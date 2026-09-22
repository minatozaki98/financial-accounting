[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$ApiPort = 5296,
    [int]$WebPort = 5173,
    [string]$WorkingDirectory,
    [string]$ConnectionString,
    [switch]$SkipDatabase,
    [switch]$SkipWebInstall,
    [switch]$SkipBrowserSmoke,
    [switch]$KeepRunning,
    [switch]$ReturnFailureRecord,
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
$canonicalRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$repositoryRoot = if ($WorkingDirectory) { Get-ThesisRepositoryRoot -StartPath $WorkingDirectory } else { $canonicalRoot }
$provenance = Get-GitProvenance -WorkingDirectory $repositoryRoot
$sha256 = [Security.Cryptography.SHA256]::Create()
try { $pathFingerprint = -join ($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($repositoryRoot.ToLowerInvariant())) | ForEach-Object { $_.ToString('x2') }) }
finally { $sha256.Dispose() }
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$apiUrl = "http://localhost:$ApiPort"
$webUrl = "http://localhost:$WebPort"
$allowedOrigins = @("http://localhost:$WebPort", "http://127.0.0.1:$WebPort")

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $ConnectionString = if (-not [string]::IsNullOrWhiteSpace($env:AppSettings__ConnectionStrings)) {
        $env:AppSettings__ConnectionStrings
    } else {
        [string](Get-Content (Join-Path $repositoryRoot 'API/appsettings.json') -Raw | ConvertFrom-Json).AppSettings.ConnectionStrings
    }
}
if (-not (Test-LocalSqlTarget $ConnectionString)) { throw 'Refusing non-local database target for the thesis demo.' }
$connectionBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
if ([string]$connectionBuilder.InitialCatalog -ne 'Financial') { throw 'The thesis demo supports only the Financial database catalog.' }

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
    FrontendApiUrl = $apiUrl
    AllowedOrigins = $allowedOrigins
    Commit = $provenance.Commit
    WorkingDirectory = '.'
    WorkingDirectoryFingerprint = $pathFingerprint
    Health = [pscustomobject]@{ Live = $false; Ready = $false }
    Smoke = [pscustomobject]@{ WebRoot = $false }
    BrowserSmoke = 'NOT_RUN'
    OwnedPids = @()
    Failure = $null
}
if (-not $PSCmdlet.ShouldProcess("$apiUrl and $webUrl", 'Start thesis API and web demonstration')) {
    if ($OutputPath) { $null = Write-ThesisJson -InputObject $whatIfResult -Path $OutputPath }
    return $whatIfResult
}

if (-not $SkipDatabase) {
    $null = & (Join-Path $PSScriptRoot 'Initialize-ThesisDatabase.ps1') -ConnectionString $ConnectionString
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
$browserSmoke = 'NOT_RUN'

try {
    $oldConnection = $env:AppSettings__ConnectionStrings
    $oldOrigin0 = $env:AppSettings__AllowedOrigins__0
    $oldOrigin1 = $env:AppSettings__AllowedOrigins__1
    $env:AppSettings__ConnectionStrings = $ConnectionString
    $env:AppSettings__AllowedOrigins__0 = $allowedOrigins[0]
    $env:AppSettings__AllowedOrigins__1 = $allowedOrigins[1]
    $apiProcess = Start-Process -FilePath $ApiExecutable -ArgumentList $ApiArgumentList -WorkingDirectory $repositoryRoot -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory 'api.out.log') -RedirectStandardError (Join-Path $logDirectory 'api.err.log')
    if ($null -eq $oldConnection) { Remove-Item Env:AppSettings__ConnectionStrings -ErrorAction SilentlyContinue } else { $env:AppSettings__ConnectionStrings = $oldConnection }
    if ($null -eq $oldOrigin0) { Remove-Item Env:AppSettings__AllowedOrigins__0 -ErrorAction SilentlyContinue } else { $env:AppSettings__AllowedOrigins__0 = $oldOrigin0 }
    if ($null -eq $oldOrigin1) { Remove-Item Env:AppSettings__AllowedOrigins__1 -ErrorAction SilentlyContinue } else { $env:AppSettings__AllowedOrigins__1 = $oldOrigin1 }
    $ownedPids.Add($apiProcess.Id)
    $oldViteApi = $env:VITE_API_BASE_URL
    $env:VITE_API_BASE_URL = $apiUrl
    $webProcess = Start-Process -FilePath $WebExecutable -ArgumentList $WebArgumentList -WorkingDirectory $repositoryRoot -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDirectory 'web.out.log') -RedirectStandardError (Join-Path $logDirectory 'web.err.log')
    if ($null -eq $oldViteApi) { Remove-Item Env:VITE_API_BASE_URL -ErrorAction SilentlyContinue } else { $env:VITE_API_BASE_URL = $oldViteApi }
    $ownedPids.Add($webProcess.Id)

    $probeResults = @()
    foreach ($path in $ApiProbePaths) {
        $probeResults += Wait-ThesisUrl -Url ($apiUrl.TrimEnd('/') + $path) -TimeoutSeconds $StartupTimeoutSeconds
    }
    $live = $probeResults.Count -gt 0 -and [bool]$probeResults[0]
    $ready = if ($probeResults.Count -gt 1) { [bool]$probeResults[1] } else { $live }
    $webRoot = Wait-ThesisUrl -Url $webUrl -TimeoutSeconds $StartupTimeoutSeconds
    if ($live -and $ready -and $webRoot -and -not $SkipBrowserSmoke -and $usingDefaultWeb) {
        $oldWebBase = $env:WEB_BASE_URL
        $oldLiveE2e = $env:RUN_LIVE_E2E
        $oldExpectedApi = $env:EXPECTED_API_BASE_URL
        $env:WEB_BASE_URL = $webUrl
        $env:RUN_LIVE_E2E = '1'
        $env:EXPECTED_API_BASE_URL = $apiUrl
        try {
            $browserResult = Invoke-ThesisCommand -FilePath (Get-Command npm.cmd -ErrorAction Stop).Source -ArgumentList @('run','test:e2e','--prefix','WEB') -WorkingDirectory $repositoryRoot
            $browserSmoke = if ($browserResult.ExitCode -eq 0) { 'PASS' } else { 'FAIL' }
            if ($browserResult.ExitCode -ne 0) { $failure = "Browser smoke failed: $($browserResult.Output -join ' ')" }
        }
        finally {
            if ($null -eq $oldWebBase) { Remove-Item Env:WEB_BASE_URL -ErrorAction SilentlyContinue } else { $env:WEB_BASE_URL = $oldWebBase }
            if ($null -eq $oldLiveE2e) { Remove-Item Env:RUN_LIVE_E2E -ErrorAction SilentlyContinue } else { $env:RUN_LIVE_E2E = $oldLiveE2e }
            if ($null -eq $oldExpectedApi) { Remove-Item Env:EXPECTED_API_BASE_URL -ErrorAction SilentlyContinue } else { $env:EXPECTED_API_BASE_URL = $oldExpectedApi }
        }
    }
    elseif ($SkipBrowserSmoke -or -not $usingDefaultWeb) { $browserSmoke = 'SKIPPED' }
    if ($live -and $ready -and $webRoot -and $browserSmoke -ne 'FAIL') { $status = 'PASS' }
    else { if ([string]::IsNullOrWhiteSpace($failure)) { $failure = 'One or more readiness probes did not succeed before the timeout.' } }
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
    FrontendApiUrl = $apiUrl
    AllowedOrigins = $allowedOrigins
    Commit = $provenance.Commit
    WorkingDirectory = '.'
    WorkingDirectoryFingerprint = $pathFingerprint
    Health = [pscustomobject]@{ Live = $live; Ready = $ready }
    Smoke = [pscustomobject]@{ WebRoot = $webRoot }
    BrowserSmoke = $browserSmoke
    OwnedPids = @($ownedPids)
    Failure = $failure
}
if ($OutputPath) { $null = Write-ThesisJson -InputObject $result -Path $OutputPath }
if ($status -eq 'FAIL' -and -not $ReturnFailureRecord) { throw $failure }
return $result
