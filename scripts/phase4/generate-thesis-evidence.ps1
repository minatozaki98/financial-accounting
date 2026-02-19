param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,
    [string]$PerformanceDir = "Document/performance",
    [string]$SecurityDir = "Document/security"
)

$ErrorActionPreference = "Stop"

$fullPerformanceDir = [System.IO.Path]::GetFullPath($PerformanceDir)
$fullSecurityDir = [System.IO.Path]::GetFullPath($SecurityDir)
$summaryPath = Join-Path $fullPerformanceDir "test-summary-$RunId.md"

if (-not (Test-Path $summaryPath)) {
    throw "Summary not found for run id '$RunId': $summaryPath"
}

$evidenceMdPath = Join-Path $fullPerformanceDir "thesis-evidence-$RunId.md"
$evidenceCsvPath = Join-Path $fullPerformanceDir "thesis-evidence-$RunId.csv"

$summaryLines = Get-Content -Path $summaryPath
$keyValues = New-Object System.Collections.Generic.List[object]

foreach ($line in $summaryLines) {
    if ($line -match '^-\s+([^:]+):\s*(.*)$') {
        $keyValues.Add([pscustomobject]@{
            Metric = $matches[1].Trim()
            Value = $matches[2].Trim()
        })
    }
}

$latestZapBaseline = Get-ChildItem -Path $fullSecurityDir -Filter "zap-baseline-$RunId*" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$latestZapApi = Get-ChildItem -Path $fullSecurityDir -Filter "zap-api-$RunId*" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$runArtifacts = Get-ChildItem -Path $fullPerformanceDir -Recurse -File | Where-Object { $_.Name -like "*$RunId*" }

$md = New-Object System.Text.StringBuilder
$null = $md.AppendLine("# Thesis Evidence Package ($RunId)")
$null = $md.AppendLine()
$null = $md.AppendLine("## Source Summary")
$null = $md.AppendLine("- Summary Path: $summaryPath")
$null = $md.AppendLine("- GeneratedAtUtc: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')")
$null = $md.AppendLine()
$null = $md.AppendLine("## Parsed Metrics")
if ($keyValues.Count -eq 0) {
    $null = $md.AppendLine("- No key/value metrics could be parsed from summary.")
}
else {
    foreach ($kv in $keyValues) {
        $null = $md.AppendLine("- $($kv.Metric): $($kv.Value)")
    }
}
$null = $md.AppendLine()
$null = $md.AppendLine("## Security Artifacts")
$null = $md.AppendLine("- ZAP Baseline: $(if ($latestZapBaseline) { $latestZapBaseline.FullName } else { 'Not found' })")
$null = $md.AppendLine("- ZAP API: $(if ($latestZapApi) { $latestZapApi.FullName } else { 'Not found' })")
$null = $md.AppendLine()
$null = $md.AppendLine("## Performance Artifacts")
if ($runArtifacts.Count -eq 0) {
    $null = $md.AppendLine("- No run-tagged performance artifacts found.")
}
else {
    foreach ($artifact in $runArtifacts) {
        $null = $md.AppendLine("- $($artifact.FullName)")
    }
}

[System.IO.File]::WriteAllText($evidenceMdPath, $md.ToString())
$keyValues | Export-Csv -Path $evidenceCsvPath -NoTypeInformation -Encoding UTF8

[pscustomobject]@{
    RunId = $RunId
    SummaryPath = $summaryPath
    EvidenceMarkdownPath = $evidenceMdPath
    EvidenceCsvPath = $evidenceCsvPath
    MetricCount = $keyValues.Count
}
