[CmdletBinding()]
param(
    [ValidateSet('Fast', 'Full')]
    [string]$Mode = 'Fast',
    [string]$OutputDirectory = 'docs/appendix/verification-runs',
    [object[]]$CommandPlan,
    [switch]$SkipEnvironmentAudit,
    [switch]$ReturnFailureRecord
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
if ($Mode -eq 'Full') {
    throw 'Full verification is branch-specific. Use Invoke-ResearchVerification.ps1 with exact role, commit, runtime evidence, and tool inputs.'
}
$runId = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$outputDirectoryFull = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
}
$null = New-Item -ItemType Directory -Path $outputDirectoryFull -Force

if (-not $CommandPlan) {
    $npm = if ($env:OS -eq 'Windows_NT') { 'npm.cmd' } else { 'npm' }
    $CommandPlan = @(
        [pscustomobject]@{ Name='dotnet-build'; Required=$true; File='dotnet'; Args=@('build','API/API.sln','-c','Release','--nologo') },
        [pscustomobject]@{ Name='dotnet-unit'; Required=$true; File='dotnet'; Args=@('test','tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj','-c','Release','--nologo') },
        [pscustomobject]@{ Name='dotnet-integration'; Required=$true; File='dotnet'; Args=@('test','tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj','-c','Release','--nologo') },
        [pscustomobject]@{ Name='web-install'; Required=$true; File=$npm; Args=@('ci','--prefix','WEB') },
        [pscustomobject]@{ Name='web-test'; Required=$true; File=$npm; Args=@('test','--prefix','WEB') },
        [pscustomobject]@{ Name='web-build'; Required=$true; File=$npm; Args=@('run','build','--prefix','WEB') }
    )
}

$environment = if ($SkipEnvironmentAudit) {
    [pscustomobject]@{ Status = 'SKIPPED'; BlockingReasons = @() }
} else {
    & (Join-Path $PSScriptRoot 'Test-ThesisEnvironment.ps1') -Mode $Mode
}

$commandResults = New-Object System.Collections.Generic.List[object]
foreach ($command in $CommandPlan) {
    $execution = Invoke-ThesisCommand -FilePath ([string]$command.File) -ArgumentList @($command.Args) -WorkingDirectory $repositoryRoot
    $required = [bool]$command.Required
    $commandStatus = if ($execution.ExitCode -eq 0) { 'PASS' } elseif ($required) { 'FAIL' } else { 'SKIPPED' }
    $commandResults.Add([pscustomobject]@{
        Name = [string]$command.Name
        Required = $required
        File = [System.IO.Path]::GetFileName([string]$command.File)
        Arguments = @($command.Args | ForEach-Object { Protect-LogText ([string]$_) })
        ExitCode = $execution.ExitCode
        DurationMs = $execution.DurationMs
        Status = $commandStatus
        Output = @($execution.Output)
    })
}

$requiredFailures = @($commandResults | Where-Object { $_.Required -and $_.Status -eq 'FAIL' })
$optionalSkips = @($commandResults | Where-Object { -not $_.Required -and $_.Status -eq 'SKIPPED' })
$status = if ($environment.Status -eq 'ENVIRONMENT_BLOCKED') {
    'ENVIRONMENT_BLOCKED'
} elseif ($requiredFailures.Count -gt 0) {
    'FAIL'
} elseif ($optionalSkips.Count -gt 0) {
    'PASS_WITH_SKIPS'
} else {
    'PASS'
}

$git = Get-GitProvenance -WorkingDirectory $repositoryRoot
$record = [pscustomobject]@{
    SchemaVersion = 1
    RunId = $runId
    CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
    Mode = $Mode
    Status = $status
    Git = [pscustomobject]@{
        Branch = $git.Branch
        Commit = $git.Commit
        Dirty = $git.Dirty
        DirtyEntryCount = $git.DirtyEntryCount
    }
    EnvironmentStatus = $environment.Status
    BlockingReasons = @($environment.BlockingReasons)
    Commands = @($commandResults.ToArray())
}

$baseName = "verification-$($Mode.ToLowerInvariant())-$runId"
$jsonPath = Join-Path $outputDirectoryFull "$baseName.json"
$markdownPath = Join-Path $outputDirectoryFull "$baseName.md"
$null = Write-ThesisJson -InputObject $record -Path $jsonPath

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Thesis Verification Run $runId")
$lines.Add('')
$lines.Add("- Mode: $Mode")
$lines.Add("- Status: $status")
$lines.Add("- Branch: $($git.Branch)")
$lines.Add("- Commit: $($git.Commit)")
$lines.Add("- Environment: $($environment.Status)")
$lines.Add('')
$lines.Add('| Command | Required | Status | Exit | Duration (ms) |')
$lines.Add('|---|---:|---|---:|---:|')
foreach ($command in $commandResults) {
    $lines.Add("| $($command.Name) | $($command.Required) | $($command.Status) | $($command.ExitCode) | $($command.DurationMs) |")
}
[System.IO.File]::WriteAllLines($markdownPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

$record | Add-Member -NotePropertyName JsonPath -NotePropertyValue $jsonPath
$record | Add-Member -NotePropertyName MarkdownPath -NotePropertyValue $markdownPath
if ($status -in @('FAIL','ENVIRONMENT_BLOCKED') -and -not $ReturnFailureRecord) {
    throw "Thesis verification ended with status $status. Record: $jsonPath"
}
return $record
