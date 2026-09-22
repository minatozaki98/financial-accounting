[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$ApiPort = 5296,
    [int]$WebPort = 5173,
    [switch]$SkipDatabase,
    [switch]$SkipWebInstall,
    [switch]$KeepRunning,
    [int]$StartupTimeoutSeconds = 120,
    [string]$ApiExecutable,
    [string[]]$ApiArgumentList = @(),
    [string[]]$ApiProbePaths = @('/health/live', '/health/ready'),
    [string]$WebExecutable,
    [string[]]$WebArgumentList = @(),
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$apiUrl = "http://localhost:$ApiPort"
$webUrl = "http://localhost:$WebPort"

function Wait-ThesisUrl {
    param([string]$Url, [int]$TimeoutSeconds)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) { return $true }
        }
        catch { }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

function Stop-OwnedProcessTree {
    param([int]$ProcessId)

    if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return }
    if (Get-Command taskkill -ErrorAction SilentlyContinue) {
        & taskkill /PID $ProcessId /T /F 2>$null | Out-Null
    }
    else {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

foreach ($port in @($ApiPort, $WebPort)) {
    $owner = Get-PortOwner -Port $port
    if ($owner.IsListening) {
        throw "Required demo port $port is already owned by unrelated PID $($owner.Pid)."
    }
}

$whatIfResult = [pscustomobject]@{
    SchemaVersion = 1
    RunId = $runId
    Status = 'WHATIF'
    ApiPid = $null
    WebPid = $null
    ApiUrl = $apiUrl
    WebUrl = $webUrl
    Health = [pscustomobject]@{ Live = $false; Ready = $false }
    Smoke = [pscustomobject]@{ WebRoot = $false }
    OwnedPids = @()
    Failure = $null
}
if (-not $PSCmdlet.ShouldProcess("$apiUrl and $webUrl", 'Start thesis API and web demonstration')) {
    if ($OutputPath) { $null = Write-ThesisJson -InputObject $whatIfResult -Path $OutputPath }
    return $whatIfResult
}

if (-not $SkipDatabase) {
    $null = & (Join-Path $PSScriptRoot 'Initialize-ThesisDatabase.ps1')
}

$usingDefaultApi = [string]::IsNullOrWhiteSpace($ApiExecutable)
if ($usingDefaultApi) {
    $ApiExecutable = (Get-Command dotnet -ErrorAction Stop).Source
    $ApiArgumentList = @('run', '--project', 'API/API.csproj', '--urls', $apiUrl, '--environment', 'Development')
}
$usingDefaultWeb = [string]::IsNullOrWhiteSpace($WebExecutable)
if ($usingDefaultWeb) {
    if (-not $SkipWebInstall -and -not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'WEB/node_modules'))) {
        $npmInstall = Invoke-ThesisCommand -FilePath (Get-Command npm.cmd -ErrorAction Stop).Source -ArgumentList @('ci', '--prefix', 'WEB') -WorkingDirectory $repositoryRoot
        if ($npmInstall.ExitCode -ne 0) { throw "Frontend dependency installation failed: $($npmInstall.Output -join ' ')" }
    }
    $WebExecutable = (Get-Command npm.cmd -ErrorAction Stop).Source
    $WebArgumentList = @('run', 'dev', '--prefix', 'WEB', '--', '--port', "$WebPort")
}

$logDirectory = Join-Path $repositoryRoot ".tmp/thesis-demo/$runId"
$null = New-Item -ItemType Directory -Path $logDirectory -Force
$ownedPids = New-Object System.Collections.Generic.List[int]
$apiProcess = $null
$webProcess = $null
$status = 'FAIL'
$failure = $null
$live = $false
$ready = $false
$webRoot = $false

try {
    $apiProcess = Start-Process -FilePath $ApiExecutable -ArgumentList $ApiArgumentList -WorkingDirectory $repositoryRoot -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory 'api.out.log') -RedirectStandardError (Join-Path $logDirectory 'api.err.log')
    $ownedPids.Add($apiProcess.Id)
    $webProcess = Start-Process -FilePath $WebExecutable -ArgumentList $WebArgumentList -WorkingDirectory $repositoryRoot -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory 'web.out.log') -RedirectStandardError (Join-Path $logDirectory 'web.err.log')
    $ownedPids.Add($webProcess.Id)

    $probeResults = @()
    foreach ($path in $ApiProbePaths) {
        $probeResults += Wait-ThesisUrl -Url ($apiUrl.TrimEnd('/') + $path) -TimeoutSeconds $StartupTimeoutSeconds
    }
    $live = $probeResults.Count -gt 0 -and [bool]$probeResults[0]
    $ready = if ($probeResults.Count -gt 1) { [bool]$probeResults[1] } else { $live }
    $webRoot = Wait-ThesisUrl -Url $webUrl -TimeoutSeconds $StartupTimeoutSeconds
    if ($live -and $ready -and $webRoot) { $status = 'PASS' }
    else { $failure = 'One or more readiness probes did not succeed before the timeout.' }
}
catch {
    $failure = Protect-LogText $_.Exception.Message
}
finally {
    if (-not $KeepRunning -or $status -ne 'PASS') {
        foreach ($processId in @($ownedPids)) { Stop-OwnedProcessTree -ProcessId $processId }
    }
}

$result = [pscustomobject]@{
    SchemaVersion = 1
    RunId = $runId
    Status = $status
    ApiPid = if ($apiProcess) { $apiProcess.Id } else { $null }
    WebPid = if ($webProcess) { $webProcess.Id } else { $null }
    ApiUrl = $apiUrl
    WebUrl = $webUrl
    Health = [pscustomobject]@{ Live = $live; Ready = $ready }
    Smoke = [pscustomobject]@{ WebRoot = $webRoot }
    OwnedPids = @($ownedPids)
    Failure = $failure
}
if ($OutputPath) { $null = Write-ThesisJson -InputObject $result -Path $OutputPath }
return $result
