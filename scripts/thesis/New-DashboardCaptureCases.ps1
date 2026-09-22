[CmdletBinding()]
param(
    [string]$ManifestPath = 'docs/appendix/dashboard-capture-manifest.json',
    [string]$OutputPath = '.tmp/dashboard-cases.json',
    [string]$JMeterDashboardBaseUrl = 'http://127.0.0.1:8765'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Thesis.Common.psm1') -Force
$repositoryRoot = Get-ThesisRepositoryRoot -StartPath $PSScriptRoot
$manifest = Get-Content (Join-Path $repositoryRoot $ManifestPath) -Raw | ConvertFrom-Json
$cases = @()

foreach ($capture in $manifest.captures) {
    $metrics = @()
    foreach ($property in $capture.displayedMetrics.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value
        $metric = [ordered]@{ name=$name; expectedValue=$value; sourceKind='path'; sourcePath=''; pagePattern='' }
        if ($capture.tool -eq 'sonarqube') {
            $metric.sourcePath = switch ($name) {
                'qualityGate' { 'qualityGate' }
                'totalIssues' { 'totalIssues' }
                'coverage' { 'metrics.coverage' }
                'codeSmells' { 'metrics.code_smells' }
                default { throw "Unknown SonarQube metric: $name" }
            }
            $metric.pagePattern = switch ($name) {
                'qualityGate' { 'Quality Gate' }
                'coverage' { [regex]::Escape("$value%") }
                'totalIssues' { "$value\s*issues|No Issues" }
                default { "\b$([regex]::Escape([string]$value))\b" }
            }
        }
        elseif ($capture.tool -eq 'zap') {
            $metric.sourceKind = 'zap-risk-count'
            $metric.Remove('sourcePath')
            $metric.riskCode = switch ($name) { 'high' {3}; 'medium' {2}; 'low' {1}; 'informational' {0}; default { throw "Unknown ZAP metric: $name" } }
            $metric.pagePattern = "$name\s+$value"
        }
        elseif ($capture.tool -eq 'jmeter') {
            $metric.sourcePath = switch ($name) {
                'sampleCount' { 'Total.sampleCount' }
                'errorPct' { 'Total.errorPct' }
                'p95Ms' { 'Total.pct2ResTime' }
                'throughput' { 'Total.throughput' }
                default { throw "Unknown JMeter metric: $name" }
            }
            $metric.pagePattern = if ($name -eq 'sampleCount') { "\b$value\b" } else { [regex]::Escape(([double]$value).ToString('0.00')) }
        }
        $metrics += [pscustomobject]$metric
    }

    $sourceUrl = [string]$capture.sourceUrl
    $case = [ordered]@{
        name = "$($capture.tool) $($capture.view)"
        tool = $capture.tool
        view = $capture.view
        sourceUrl = $sourceUrl
        sourceUrlLabel = $capture.sourceUrl
        readySelector = 'body'
        imagePath = $capture.imagePath
        evidenceClassification = $capture.evidenceClassification
        evidenceRole = $capture.evidenceRole
        branch = $capture.branch
        commit = $capture.commit
        runId = $capture.runId
        toolVersion = $capture.toolVersion
        sourceArtifact = $capture.sourceArtifact
        metrics = $metrics
    }
    if ($capture.tool -eq 'sonarqube') {
        $sonarSummary = Get-Content (Join-Path $repositoryRoot $capture.sourceArtifact) -Raw | ConvertFrom-Json
        $case.sourceUrl = if ($capture.view -like '*issues*') {
            "http://localhost:9000/project/issues?id=$($sonarSummary.projectKey)&resolved=false"
        } else {
            "http://localhost:9000/dashboard?id=$($sonarSummary.projectKey)"
        }
        $case.sourceUrlLabel = $case.sourceUrl
        $case.loginUrl = 'http://localhost:9000/sessions/new'
    }
    elseif ($capture.tool -eq 'zap') {
        $case.sourceUrl = ([Uri](Join-Path $repositoryRoot $capture.sourceUrl)).AbsoluteUri
        $case.readySelector = 'table.summary'
    }
    elseif ($capture.tool -eq 'jmeter') {
        $dashboardPath = ([string]$capture.sourceArtifact) -replace '/statistics\.json$', '/index.html'
        $servedPath = $dashboardPath -replace '^docs/appendix/verification-runs/research/jmeter/', ''
        $case.sourceUrl = "$($JMeterDashboardBaseUrl.TrimEnd('/'))/$servedPath"
        $case.sourceUrlLabel = $dashboardPath
        $case.readySelector = '#statisticsTable'
        $case.captureSelector = '#statisticsTable'
    }
    $cases += [pscustomobject]$case
}

$fullOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath)) }
$parent = Split-Path $fullOutput -Parent
if (-not (Test-Path $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
[IO.File]::WriteAllText($fullOutput, ($cases | ConvertTo-Json -Depth 20) + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
return $fullOutput
