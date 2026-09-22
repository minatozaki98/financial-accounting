Set-StrictMode -Version Latest

function Wait-SonarComputeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TaskUri,
        [hashtable]$Headers = @{},
        [int]$TimeoutSeconds = 180,
        [int]$PollIntervalMilliseconds = 1000,
        [scriptblock]$Invoker = { param($uri, $headers) Invoke-RestMethod -Uri $uri -Headers $headers -Method Get }
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $response = & $Invoker $TaskUri $Headers
        $task = $response.task
        if (-not $task) { throw 'SonarQube Compute Engine response did not contain a task.' }
        switch ([string]$task.status) {
            'SUCCESS' {
                if ([string]::IsNullOrWhiteSpace([string]$task.analysisId)) { throw 'Successful SonarQube task did not contain an analysis id.' }
                return $task
            }
            'FAILED' { throw "SonarQube Compute Engine task failed: $($task.errorMessage)" }
            'CANCELED' { throw 'SonarQube Compute Engine task was canceled.' }
        }
        Start-Sleep -Milliseconds $PollIntervalMilliseconds
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Timed out waiting for SonarQube Compute Engine task: $TaskUri"
}

function Get-JMeterGateOutcome {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Summary)

    $thresholds = @{
        p50 = @{ MaxErrorPct = 0.5; MaxP95 = 300 }
        p100 = @{ MaxErrorPct = 1.0; MaxP95 = 500 }
        p500 = @{ MaxErrorPct = 2.0; MaxP95 = 1200 }
    }
    $failures = New-Object System.Collections.Generic.List[string]
    $profiles = @{}
    foreach ($profile in $Summary.profiles) { $profiles[[string]$profile.profile] = $profile }
    foreach ($name in @('p50','p100','p500')) {
        if (-not $profiles.ContainsKey($name)) { $failures.Add("Missing required profile $name."); continue }
        $profile = $profiles[$name]
        if ([double]$profile.errorPct -gt $thresholds[$name].MaxErrorPct) { $failures.Add("$name errorPct $($profile.errorPct) exceeds $($thresholds[$name].MaxErrorPct).") }
        if ([double]$profile.p95Ms -gt $thresholds[$name].MaxP95) { $failures.Add("$name p95 $($profile.p95Ms) exceeds $($thresholds[$name].MaxP95) ms.") }
    }
    [pscustomobject]@{ Status = if ($failures.Count) { 'FAIL' } else { 'PASS' }; Failures = @($failures.ToArray()) }
}

function Test-RuntimeEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][string]$ExpectedCommit,
        [Parameter(Mandatory = $true)][string]$ExpectedBaseUrl,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingDirectory
    )

    if ($Evidence.Status -ne 'PASS') { throw 'Runtime evidence status is not PASS.' }
    if ([string]$Evidence.Commit -ne $ExpectedCommit) { throw 'Runtime evidence commit does not match the measurement commit.' }
    if ([string]$Evidence.ApiUrl -ne $ExpectedBaseUrl) { throw 'Runtime evidence API URL does not match the measurement base URL.' }
    $expectedFullPath = [System.IO.Path]::GetFullPath($ExpectedWorkingDirectory)
    if ($Evidence.PSObject.Properties['WorkingDirectoryFingerprint']) {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { $expectedFingerprint = -join ($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($expectedFullPath.ToLowerInvariant())) | ForEach-Object { $_.ToString('x2') }) }
        finally { $sha256.Dispose() }
        if ([string]$Evidence.WorkingDirectoryFingerprint -ne $expectedFingerprint) { throw 'Runtime evidence working directory fingerprint does not match the measurement checkout.' }
    }
    elseif ([System.IO.Path]::GetFullPath([string]$Evidence.WorkingDirectory) -ne $expectedFullPath) { throw 'Runtime evidence working directory does not match the measurement checkout.' }
    if (@($Evidence.OwnedPids) -notcontains [int]$Evidence.ApiPid) { throw 'Runtime evidence API PID is not in the owned process list.' }
    if (-not (Get-Process -Id ([int]$Evidence.ApiPid) -ErrorAction SilentlyContinue)) { throw 'Runtime evidence API process is not running.' }
    return $true
}

Export-ModuleMember -Function @('Wait-SonarComputeTask','Get-JMeterGateOutcome','Test-RuntimeEvidence')
