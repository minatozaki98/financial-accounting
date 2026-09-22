[CmdletBinding()]
param(
    [ValidateSet('Fast', 'Demo', 'Full')]
    [string]$Mode = 'Fast',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'Thesis.Common.psm1'
Import-Module $modulePath -Force

$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$git = Get-GitProvenance -WorkingDirectory $repositoryRoot
$blockingReasons = New-Object System.Collections.Generic.List[string]

function Get-CommandVersion {
    param([string]$Name, [string[]]$Arguments)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{ Present = $false; Version = $null; Path = $null }
    }

    $result = Invoke-ThesisCommand -FilePath $command.Source -ArgumentList $Arguments -WorkingDirectory $repositoryRoot
    [pscustomobject]@{
        Present = $true
        Version = if ($result.ExitCode -eq 0) { ($result.Output -join ' ').Trim() } else { $null }
        Path = $command.Source
    }
}

$gitCommand = Get-CommandVersion -Name 'git' -Arguments @('--version')
$dotnet = Get-CommandVersion -Name 'dotnet' -Arguments @('--version')
$node = Get-CommandVersion -Name 'node' -Arguments @('--version')
$npm = Get-CommandVersion -Name 'npm' -Arguments @('--version')

foreach ($requiredCommand in @(
    @{ Name = 'Git'; Probe = $gitCommand },
    @{ Name = '.NET SDK'; Probe = $dotnet },
    @{ Name = 'Node.js'; Probe = $node },
    @{ Name = 'npm'; Probe = $npm }
)) {
    if (-not $requiredCommand.Probe.Present) {
        $blockingReasons.Add("$($requiredCommand.Name) is unavailable.")
    }
}

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$dockerClientVersion = $null
$dockerServerVersion = $null
$dockerServerAvailable = $false
if ($dockerCommand) {
    $clientProbe = Invoke-ThesisCommand -FilePath $dockerCommand.Source -ArgumentList @('version', '--format', '{{.Client.Version}}') -WorkingDirectory $repositoryRoot
    if ($clientProbe.ExitCode -eq 0) { $dockerClientVersion = ($clientProbe.Output -join ' ').Trim() }
    $serverProbe = Invoke-ThesisCommand -FilePath $dockerCommand.Source -ArgumentList @('version', '--format', '{{.Server.Version}}') -WorkingDirectory $repositoryRoot
    if ($serverProbe.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace(($serverProbe.Output -join ''))) {
        $dockerServerAvailable = $true
        $dockerServerVersion = ($serverProbe.Output -join ' ').Trim()
    }
}

$docker = [pscustomobject]@{
    ClientPresent = $null -ne $dockerCommand
    ClientVersion = $dockerClientVersion
    ServerAvailable = $dockerServerAvailable
    ServerVersion = $dockerServerVersion
}

$sqlServices = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^MSSQL' } | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Status = [string]$_.Status }
})
$sqlServer = [pscustomobject]@{
    Running = @($sqlServices | Where-Object { $_.Status -eq 'Running' }).Count -gt 0
    Services = $sqlServices
}
$sqlCmdCommand = Get-Command sqlcmd -ErrorAction SilentlyContinue
$sqlCmd = [pscustomobject]@{
    Present = $null -ne $sqlCmdCommand
    Path = if ($sqlCmdCommand) { $sqlCmdCommand.Source } else { $null }
}

$requiredPaths = @(
    'API/API.csproj',
    'API/API.sln',
    'WEB/package.json',
    'Document/sql/financial_accounting_schema.sql',
    'Document/performance/jmeter/financial-api-load-test.jmx',
    'Document/performance/jmeter/financial-api-soak-test.jmx',
    'Document/performance/jmeter/financial-api-spike-test.jmx',
    'scripts/phase4/run-sonarqube-scan.ps1',
    'scripts/phase4/run-zap-baseline.ps1',
    'scripts/phase4/run-zap-api.ps1',
    'scripts/phase4/run-jmeter-thesis-matrix.ps1'
)
$files = @($requiredPaths | ForEach-Object {
    [pscustomobject]@{ Path = $_; Exists = Test-Path -LiteralPath (Join-Path $repositoryRoot $_) }
})
foreach ($missingFile in @($files | Where-Object { -not $_.Exists })) {
    $blockingReasons.Add("Required file is missing: $($missingFile.Path)")
}

$ports = @(5296, 5173, 9000, 8080, 8088, 8090 | ForEach-Object { Get-PortOwner -Port $_ })
if ($Mode -in @('Demo', 'Full')) {
    if (-not $sqlServer.Running) { $blockingReasons.Add('No local SQL Server service is running.') }
    if (-not $sqlCmd.Present) { $blockingReasons.Add('sqlcmd is unavailable.') }
    foreach ($occupied in @($ports | Where-Object { $_.Port -in @(5296, 5173) -and $_.IsListening })) {
        $blockingReasons.Add("Required demo port $($occupied.Port) is owned by PID $($occupied.Pid).")
    }
}
if ($Mode -eq 'Full' -and -not $docker.ServerAvailable) {
    $blockingReasons.Add('Docker server is unavailable.')
}

$sonarTokenPresent = -not [string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)
$gitForOutput = [pscustomobject]@{
    Root = '.'
    Branch = $git.Branch
    Commit = $git.Commit
    Dirty = $git.Dirty
    DirtyEntryCount = $git.DirtyEntryCount
    Upstream = $git.Upstream
    Ahead = $git.Ahead
    Behind = $git.Behind
}
$result = [pscustomobject]@{
    SchemaVersion = 1
    CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
    Mode = $Mode
    Status = if ($blockingReasons.Count -gt 0) { 'ENVIRONMENT_BLOCKED' } else { 'PASS' }
    BlockingReasons = @($blockingReasons)
    Git = $gitForOutput
    GitCommand = $gitCommand
    DotNet = $dotnet
    Node = $node
    Npm = $npm
    Docker = $docker
    SqlServer = $sqlServer
    SqlCmd = $sqlCmd
    Ports = $ports
    Files = $files
    SonarTokenPresent = $sonarTokenPresent
    SonarStatus = if ($sonarTokenPresent) { 'READY' } else { 'SKIPPED' }
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $null = Write-ThesisJson -InputObject $result -Path $OutputPath
}

return $result
