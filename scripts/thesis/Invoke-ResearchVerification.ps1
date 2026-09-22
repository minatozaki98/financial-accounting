[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('baseline', 'sonarqube-remediation', 'zap-remediation', 'jmeter-remediation')]
    [string]$Role,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedCommit,
    [string]$Phase4Root,
    [string]$OutputDirectory = 'docs/appendix/verification-runs/research',
    [string]$BaseUrl = 'http://localhost:5296',
    [string]$OpenApiUrl = 'http://localhost:5296/swagger/v1/swagger.json',
    [string]$Username = 'admin',
    [string]$Password = '',
    [int]$PeriodId = 202601,
    [int]$AccountId = 1,
    [string]$RuntimeEvidencePath,
    [switch]$AllowDirty,
    [switch]$ReturnFailureRecord,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Thesis.Research.psm1') -Force
$canonicalRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$workingDirectoryFull = [System.IO.Path]::GetFullPath($WorkingDirectory)
if (-not (Test-Path -LiteralPath $workingDirectoryFull)) { throw "Working directory does not exist: $workingDirectoryFull" }
$actualCommit = (& git -C $workingDirectoryFull rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Unable to resolve Git commit in the working directory." }
if ($actualCommit -ne $ExpectedCommit.ToLowerInvariant()) {
    throw "Expected $ExpectedCommit but found $actualCommit."
}
$dirtyEntries = @(& git -C $workingDirectoryFull status --porcelain --untracked-files=all)
if ($dirtyEntries.Count -gt 0 -and -not $AllowDirty) { throw 'Measurement checkout must be clean.' }

if ([string]::IsNullOrWhiteSpace($Phase4Root)) {
    $Phase4Root = Join-Path $workingDirectoryFull 'scripts/phase4'
}
$phase4RootFull = [System.IO.Path]::GetFullPath($Phase4Root)
$outputDirectoryFull = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $canonicalRoot $OutputDirectory))
}
$runId = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$commitPrefix = $actualCommit.Substring(0, 8)
$sonarKeys = @{
    baseline = 'financial-accounting-thesis-baseline-v01'
    'sonarqube-remediation' = 'financial-accounting-thesis-sonarqube-v1'
    'zap-remediation' = 'financial-accounting-thesis-zap-v1'
    'jmeter-remediation' = 'financial-accounting-thesis-jmeter-v1'
}
$usesSonar = $Role -in @('baseline', 'sonarqube-remediation')
$usesZap = $Role -in @('baseline', 'zap-remediation')
$usesJMeter = $Role -in @('baseline', 'jmeter-remediation')
$runtimeEvidence = $null
if ($usesZap -or $usesJMeter) {
    if ([string]::IsNullOrWhiteSpace($RuntimeEvidencePath) -or -not (Test-Path -LiteralPath $RuntimeEvidencePath)) {
        throw 'Runtime evidence is required for ZAP and JMeter measurement roles.'
    }
    $runtimeEvidence = Get-Content -LiteralPath $RuntimeEvidencePath -Raw | ConvertFrom-Json
    $null = Test-RuntimeEvidence -Evidence $runtimeEvidence -ExpectedCommit $actualCommit -ExpectedBaseUrl $BaseUrl -ExpectedWorkingDirectory $workingDirectoryFull
}

$result = [pscustomobject]@{
    SchemaVersion = 1
    RunId = $runId
    Role = $Role
    Commit = $actualCommit
    EvidenceClassification = 'fresh-reproduction'
    Status = if ($DryRun) { 'DRY_RUN' } else { 'PENDING' }
    Failure = $null
    Docker = [pscustomobject]@{ Status = if ($DryRun) { 'DRY_RUN' } else { 'PENDING' }; ServerVersion = $null }
    Sonar = [pscustomobject]@{
        Status = if ($usesSonar) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }
        ProjectKey = $sonarKeys[$Role]
        Summary = $null
        ExecutionStatus = if ($usesSonar) { 'PENDING' } else { 'NOT_APPLICABLE' }
        GateStatus = 'NOT_EVALUATED'
        TaskId = $null
        AnalysisId = $null
    }
    ZapBaseline = [pscustomobject]@{ Status = if ($usesZap) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; ExecutionStatus='PENDING'; GateStatus='NOT_EVALUATED'; Html = $null; Json = $null; Markdown = $null }
    ZapApi = [pscustomobject]@{ Status = if ($usesZap) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; ExecutionStatus='PENDING'; GateStatus='NOT_EVALUATED'; Html = $null; Json = $null; Markdown = $null }
    JMeter = [pscustomobject]@{ Status = if ($usesJMeter) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; ExecutionStatus='PENDING'; GateStatus='NOT_EVALUATED'; GateFailures=@(); RunTag = "$Role-$commitPrefix-$runId"; Summary = $null }
    RuntimeEvidence = if ($runtimeEvidence) { [pscustomobject]@{ Commit=$runtimeEvidence.Commit; ApiPid=$runtimeEvidence.ApiPid; ApiUrl=$runtimeEvidence.ApiUrl } } else { $null }
    Phase4Root = $phase4RootFull
}

if ($DryRun) { return $result }

if ($usesSonar -and [string]::IsNullOrWhiteSpace($env:SONAR_TOKEN) -and -not $usesZap -and -not $usesJMeter) {
    $result.Sonar.Status = 'SKIPPED'
    $result.Sonar.ExecutionStatus = 'SKIPPED'
    $result.Status = 'SKIPPED'
    return $result
}

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
    $result.Docker.Status = 'ENVIRONMENT_BLOCKED'
    $result.Status = 'ENVIRONMENT_BLOCKED'
    $result.Failure = 'Docker server is unavailable.'
    if ($ReturnFailureRecord) { return $result }
    throw $result.Failure
}
$dockerProbe = Invoke-ThesisCommand -FilePath $dockerCommand.Source -ArgumentList @('version', '--format', '{{.Server.Version}}') -WorkingDirectory $canonicalRoot
if ($dockerProbe.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($dockerProbe.Output -join ''))) {
    $result.Docker.Status = 'ENVIRONMENT_BLOCKED'
    $result.Status = 'ENVIRONMENT_BLOCKED'
    $result.Failure = 'Docker server is unavailable.'
    if ($ReturnFailureRecord) { return $result }
    throw $result.Failure
}
$result.Docker.Status = 'PASS'
$result.Docker.ServerVersion = ($dockerProbe.Output -join ' ').Trim()

if ($usesSonar -and [string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
    $result.Sonar.Status = 'SKIPPED'
    if (-not $usesZap -and -not $usesJMeter) {
        $result.Status = 'SKIPPED'
        return $result
    }
}

$null = New-Item -ItemType Directory -Path $outputDirectoryFull -Force
try {
    Push-Location -LiteralPath $workingDirectoryFull
    if ($usesSonar -and $result.Sonar.Status -ne 'SKIPPED') {
        $scanScript = Join-Path $phase4RootFull 'run-sonarqube-scan.ps1'
        $summaryScript = Join-Path $phase4RootFull 'get-sonar-summary.ps1'
        $scanStarted = [DateTime]::UtcNow
        $null = & $scanScript -SonarToken $env:SONAR_TOKEN -ProjectKey $result.Sonar.ProjectKey -ProjectName "Financial Accounting Thesis $Role" -SolutionPath (Join-Path $workingDirectoryFull 'API/API.csproj')
        if ($LASTEXITCODE -ne 0) { throw "Sonar scanner failed with exit code $LASTEXITCODE." }
        $taskFile = Get-ChildItem -LiteralPath $workingDirectoryFull -Recurse -Force -Filter report-task.txt | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if (-not $taskFile -or $taskFile.LastWriteTimeUtc -lt $scanStarted.AddSeconds(-2)) { throw 'Sonar scanner did not produce a current report-task file.' }
        $taskValues = @{}; foreach ($line in Get-Content $taskFile.FullName) { if ($line -match '^([^=]+)=(.*)$') { $taskValues[$Matches[1]] = $Matches[2] } }
        if (-not $taskValues.ceTaskUrl -or -not $taskValues.ceTaskId) { throw 'Sonar report-task file is missing Compute Engine identifiers.' }
        $authRaw = "$($env:SONAR_TOKEN):"
        $headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authRaw)) }
        $task = Wait-SonarComputeTask -TaskUri $taskValues.ceTaskUrl -Headers $headers
        $gate = Invoke-RestMethod -Headers $headers -Uri "http://localhost:9000/api/qualitygates/project_status?analysisId=$($task.analysisId)"
        $result.Sonar.Summary = & $summaryScript -SonarToken $env:SONAR_TOKEN -ProjectKey $result.Sonar.ProjectKey
        $result.Sonar.TaskId = $taskValues.ceTaskId
        $result.Sonar.AnalysisId = $task.analysisId
        $result.Sonar.ExecutionStatus = 'PASS'
        $result.Sonar.GateStatus = [string]$gate.projectStatus.status
        $result.Sonar.Status = if ($result.Sonar.GateStatus -eq 'OK') { 'PASS' } else { 'FAIL' }
    }
    if ($usesZap) {
        $securityDirectory = Join-Path $outputDirectoryFull 'security'
        $baselinePrefix = "zap-baseline-$Role-$commitPrefix-$runId"
        $apiPrefix = "zap-api-$Role-$commitPrefix-$runId"
        $baselineResult = & (Join-Path $phase4RootFull 'run-zap-baseline.ps1') -TargetUrl "$BaseUrl/health/live" -ReportDir $securityDirectory -OutputPrefix $baselinePrefix -IgnoreWarnings
        $zapApiParameters = @{
            OpenApiUrl = $OpenApiUrl
            BaseUrl = $BaseUrl
            Username = $Username
            ReportDir = $securityDirectory
            OutputPrefix = $apiPrefix
            IgnoreWarnings = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($Password)) { $zapApiParameters['Password'] = $Password }
        $apiResult = & (Join-Path $phase4RootFull 'run-zap-api.ps1') @zapApiParameters
        $result.ZapBaseline = [pscustomobject]@{ Status='PASS'; ExecutionStatus='PASS'; GateStatus='PASS'; Html=$baselineResult.HtmlReportPath; Json=$baselineResult.JsonReportPath; Markdown=$baselineResult.MarkdownReportPath }
        $result.ZapApi = [pscustomobject]@{ Status='PASS'; ExecutionStatus='PASS'; GateStatus='PASS'; Html=$apiResult.HtmlReportPath; Json=$apiResult.JsonReportPath; Markdown=$apiResult.MarkdownReportPath }
    }
    if ($usesJMeter) {
        $performanceDirectory = Join-Path $outputDirectoryFull 'performance'
        $jmeterParameters = @{
            BaseUrl = $BaseUrl
            Username = $Username
            PeriodId = $PeriodId
            AccountId = $AccountId
            ResultsDir = $performanceDirectory
            RunTag = $result.JMeter.RunTag
        }
        if (-not [string]::IsNullOrWhiteSpace($Password)) { $jmeterParameters['Password'] = $Password }
        $matrixResult = & (Join-Path $phase4RootFull 'run-jmeter-thesis-matrix.ps1') @jmeterParameters
        $matrixSummary = @($matrixResult | Where-Object { $_ -and $_.PSObject.Properties['RunTag'] }) | Select-Object -Last 1
        if (-not $matrixSummary) { throw 'JMeter matrix did not return its summary object.' }
        $profiles = @()
        foreach ($profileName in @('50','100','500')) {
            $profileResult = $matrixSummary.Profiles.$profileName
            $stats = Get-Content ([string]$profileResult.StatisticsPath) -Raw | ConvertFrom-Json
            $profiles += [pscustomobject]@{ profile="p$profileName"; errorPct=[double]$stats.Total.errorPct; p95Ms=[double]$stats.Total.pct2ResTime }
        }
        $gate = Get-JMeterGateOutcome -Summary ([pscustomobject]@{ profiles=$profiles })
        $result.JMeter = [pscustomobject]@{ Status=$gate.Status; ExecutionStatus='PASS'; GateStatus=$gate.Status; GateFailures=@($gate.Failures); RunTag=$result.JMeter.RunTag; Summary=$matrixSummary }
    }

    $hasSkip = $result.Sonar.Status -eq 'SKIPPED'
    $hasGateFailure = $result.Sonar.Status -eq 'FAIL' -or $result.JMeter.GateStatus -eq 'FAIL'
    $result.Status = if ($hasGateFailure) { 'FAIL' } elseif ($hasSkip) { 'PASS_WITH_SKIPS' } else { 'PASS' }
}
catch {
    $result.Status = 'FAIL'
    $result.Failure = Protect-LogText $_.Exception.Message
    if ($usesZap -and $result.ZapBaseline.Status -eq 'PENDING') { $result.ZapBaseline.Status = 'FAIL' }
    if ($usesJMeter -and $result.JMeter.Status -eq 'PENDING') { $result.JMeter.Status = 'FAIL' }
    if ($usesSonar -and $result.Sonar.Status -eq 'PENDING') { $result.Sonar.Status = 'FAIL' }
}
finally {
    Pop-Location
}

$recordPath = Join-Path $outputDirectoryFull "research-$Role-$commitPrefix-$runId.json"
$null = Write-ThesisJson -InputObject $result -Path $recordPath
$result | Add-Member -NotePropertyName RecordPath -NotePropertyValue $recordPath
if ($result.Status -in @('FAIL','ENVIRONMENT_BLOCKED') -and -not $ReturnFailureRecord) { throw "Research verification ended with status $($result.Status). Record: $recordPath" }
return $result
