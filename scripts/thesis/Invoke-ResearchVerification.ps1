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
    [string]$Password = 'Admin@123',
    [int]$PeriodId = 202601,
    [int]$AccountId = 1,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$canonicalRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$workingDirectoryFull = [System.IO.Path]::GetFullPath($WorkingDirectory)
if (-not (Test-Path -LiteralPath $workingDirectoryFull)) { throw "Working directory does not exist: $workingDirectoryFull" }
$actualCommit = (& git -C $workingDirectoryFull rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Unable to resolve Git commit in the working directory." }
if ($actualCommit -ne $ExpectedCommit.ToLowerInvariant()) {
    throw "Expected $ExpectedCommit but found $actualCommit."
}

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
    }
    ZapBaseline = [pscustomobject]@{ Status = if ($usesZap) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; Html = $null; Json = $null; Markdown = $null }
    ZapApi = [pscustomobject]@{ Status = if ($usesZap) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; Html = $null; Json = $null; Markdown = $null }
    JMeter = [pscustomobject]@{ Status = if ($usesJMeter) { if ($DryRun) { 'DRY_RUN' } else { 'PENDING' } } else { 'NOT_APPLICABLE' }; RunTag = "$Role-$commitPrefix-$runId"; Summary = $null }
}

if ($DryRun) { return $result }

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
    $result.Docker.Status = 'ENVIRONMENT_BLOCKED'
    $result.Status = 'ENVIRONMENT_BLOCKED'
    $result.Failure = 'Docker server is unavailable.'
    return $result
}
$dockerProbe = Invoke-ThesisCommand -FilePath $dockerCommand.Source -ArgumentList @('version', '--format', '{{.Server.Version}}') -WorkingDirectory $canonicalRoot
if ($dockerProbe.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($dockerProbe.Output -join ''))) {
    $result.Docker.Status = 'ENVIRONMENT_BLOCKED'
    $result.Status = 'ENVIRONMENT_BLOCKED'
    $result.Failure = 'Docker server is unavailable.'
    return $result
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
        $null = & $scanScript -SonarToken $env:SONAR_TOKEN -ProjectKey $result.Sonar.ProjectKey -ProjectName "Financial Accounting Thesis $Role" -SolutionPath (Join-Path $workingDirectoryFull 'API/API.csproj')
        $result.Sonar.Summary = & $summaryScript -SonarToken $env:SONAR_TOKEN -ProjectKey $result.Sonar.ProjectKey
        $result.Sonar.Status = 'PASS'
    }
    if ($usesZap) {
        $securityDirectory = Join-Path $outputDirectoryFull 'security'
        $baselinePrefix = "zap-baseline-$Role-$commitPrefix-$runId"
        $apiPrefix = "zap-api-$Role-$commitPrefix-$runId"
        $baselineResult = & (Join-Path $phase4RootFull 'run-zap-baseline.ps1') -TargetUrl "$BaseUrl/health/live" -ReportDir $securityDirectory -OutputPrefix $baselinePrefix -IgnoreWarnings
        $apiResult = & (Join-Path $phase4RootFull 'run-zap-api.ps1') -OpenApiUrl $OpenApiUrl -BaseUrl $BaseUrl -Username $Username -Password $Password -ReportDir $securityDirectory -OutputPrefix $apiPrefix -IgnoreWarnings
        $result.ZapBaseline = [pscustomobject]@{ Status='PASS'; Html=$baselineResult.HtmlReportPath; Json=$baselineResult.JsonReportPath; Markdown=$baselineResult.MarkdownReportPath }
        $result.ZapApi = [pscustomobject]@{ Status='PASS'; Html=$apiResult.HtmlReportPath; Json=$apiResult.JsonReportPath; Markdown=$apiResult.MarkdownReportPath }
    }
    if ($usesJMeter) {
        $performanceDirectory = Join-Path $outputDirectoryFull 'performance'
        $matrixResult = & (Join-Path $phase4RootFull 'run-jmeter-thesis-matrix.ps1') -BaseUrl $BaseUrl -Username $Username -Password $Password -PeriodId $PeriodId -AccountId $AccountId -ResultsDir $performanceDirectory -RunTag $result.JMeter.RunTag
        $result.JMeter = [pscustomobject]@{ Status='PASS'; RunTag=$result.JMeter.RunTag; Summary=$matrixResult }
    }

    $hasSkip = $result.Sonar.Status -eq 'SKIPPED'
    $result.Status = if ($hasSkip) { 'PASS_WITH_SKIPS' } else { 'PASS' }
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
return $result
