param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineEvidenceDir,

    [Parameter(Mandatory = $true)]
    [string]$CandidateEvidenceDir,

    [Parameter(Mandatory = $true)]
    [string]$MutationManifestPath,

    [string]$HiddenSummaryPath = "",
    [string]$OutputPath = "",
    [int]$AttemptCount = 1,
    [double]$ElapsedSeconds = 1,
    [int]$ChangedLines = 1,
    [double]$PairMinimumElapsedSeconds = 1,
    [int]$PairMinimumChangedLines = 1
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Read-Json {
    param([Parameter(Mandatory = $true)][string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function ConvertTo-ItemArray {
    param($Value)

    return @(
        if ($null -eq $Value) {
            return
        }
        elseif ($Value -is [System.Array]) {
            foreach ($item in $Value) {
                $item
            }
        }
        else {
            $Value
        }
    )
}

function New-IssueSignature {
    param($Issue)
    $component = [string]$Issue.component
    if ($component.Contains(":")) {
        $component = $component -replace "^[^:]+:", ""
    }

    return "{0}|{1}|{2}" -f $Issue.rule, $component.Replace("\", "/"), $Issue.message
}

function Get-MeasureValue {
    param($Summary, [string]$Metric)
    if ($Summary.measures.PSObject.Properties.Name -contains $Metric) {
        return [double]$Summary.measures.$Metric
    }

    return 0.0
}

$baselineDirFull = Resolve-FullPath -Path $BaselineEvidenceDir
$candidateDirFull = Resolve-FullPath -Path $CandidateEvidenceDir
$manifestFull = Resolve-FullPath -Path $MutationManifestPath

$baselineIssues = ConvertTo-ItemArray (Read-Json (Join-Path $baselineDirFull "issues-open.json"))
$candidateIssues = ConvertTo-ItemArray (Read-Json (Join-Path $candidateDirFull "issues-open.json"))
$baselineSummary = Read-Json (Join-Path $baselineDirFull "summary.json")
$candidateSummary = Read-Json (Join-Path $candidateDirFull "summary.json")
$manifestDocument = Read-Json $manifestFull
$manifest = if ($manifestDocument.PSObject.Properties.Name -contains "entries") {
    ConvertTo-ItemArray $manifestDocument.entries
}
else {
    ConvertTo-ItemArray $manifestDocument
}

$candidateKeys = @{}
$candidateSignatures = @{}
foreach ($issue in $candidateIssues) {
    if (-not [string]::IsNullOrWhiteSpace($issue.key)) {
        $candidateKeys[$issue.key] = $true
    }
    $candidateSignatures[(New-IssueSignature -Issue $issue)] = $true
}

$resolved = New-Object System.Collections.Generic.List[object]
$remaining = New-Object System.Collections.Generic.List[object]
foreach ($mutation in $manifest) {
    $component = [string]$mutation.component
    if ($component.Contains(":")) {
        $component = $component -replace "^[^:]+:", ""
    }
    $signature = "{0}|{1}|{2}" -f $mutation.rule, $component.Replace("\", "/"), $mutation.baselineMessage
    $stillPresent = $false
    if (-not [string]::IsNullOrWhiteSpace($mutation.baselineIssueKey) -and $candidateKeys.ContainsKey($mutation.baselineIssueKey)) {
        $stillPresent = $true
    }
    elseif ($candidateSignatures.ContainsKey($signature)) {
        $stillPresent = $true
    }

    if ($stillPresent) {
        $remaining.Add($mutation)
    }
    else {
        $resolved.Add($mutation)
    }
}

$baselineSignatures = @{}
foreach ($issue in $baselineIssues) {
    $baselineSignatures[(New-IssueSignature -Issue $issue)] = $true
}
$newIssues = @($candidateIssues | Where-Object { -not $baselineSignatures.ContainsKey((New-IssueSignature -Issue $_)) })

$hiddenPassed = 0
$hiddenTotal = 0
if (-not [string]::IsNullOrWhiteSpace($HiddenSummaryPath)) {
    $hidden = Read-Json (Resolve-FullPath -Path $HiddenSummaryPath)
    $hiddenPassed = [int]$hidden.passed
    $hiddenTotal = [int]$hidden.total
}

$baselineVerified = [Math]::Max(1, $manifest.Count)
$issuePoints = 45.0 * [Math]::Max(0.0, (($resolved.Count - $newIssues.Count) / $baselineVerified))
$behaviorPoints = if ($hiddenTotal -gt 0) { 30.0 * ($hiddenPassed / $hiddenTotal) } else { 0.0 }

$referenceCoverage = Get-MeasureValue -Summary $baselineSummary -Metric "coverage"
$candidateCoverage = Get-MeasureValue -Summary $candidateSummary -Metric "coverage"
$coveragePoints = if ($referenceCoverage -gt 0) {
    10.0 * [Math]::Min(1.0, $candidateCoverage / $referenceCoverage)
}
else {
    0.0
}

$referenceDuplication = Get-MeasureValue -Summary $baselineSummary -Metric "duplicated_lines_density"
$candidateDuplication = Get-MeasureValue -Summary $candidateSummary -Metric "duplicated_lines_density"
if ($candidateDuplication -le $referenceDuplication) {
    $duplicationPoints = 5.0
}
elseif ($referenceDuplication -gt 0) {
    $duplicationPoints = 5.0 * ($referenceDuplication / $candidateDuplication)
}
else {
    $duplicationPoints = 0.0
}

$attemptPoints = switch ($AttemptCount) {
    1 { 4.0 }
    2 { 2.0 }
    default { 0.0 }
}
$elapsedPoints = 3.0 * ([Math]::Max(0.001, $PairMinimumElapsedSeconds) / [Math]::Max(0.001, $ElapsedSeconds))
$patchPoints = 3.0 * ([Math]::Max(1, $PairMinimumChangedLines) / [Math]::Max(1, $ChangedLines))
$efficiencyPoints = [Math]::Min(10.0, $attemptPoints + $elapsedPoints + $patchPoints)

$result = [ordered]@{
    baselineEvidenceDir = $baselineDirFull
    candidateEvidenceDir = $candidateDirFull
    mutationManifestPath = $manifestFull
    baselineVerified = $manifest.Count
    resolvedVerified = $resolved.Count
    remainingVerified = $remaining.Count
    newIssueCount = $newIssues.Count
    hiddenPassed = $hiddenPassed
    hiddenTotal = $hiddenTotal
    referenceCoverage = $referenceCoverage
    candidateCoverage = $candidateCoverage
    referenceDuplication = $referenceDuplication
    candidateDuplication = $candidateDuplication
    points = [ordered]@{
        issues = [Math]::Round($issuePoints, 4)
        behavior = [Math]::Round($behaviorPoints, 4)
        coverage = [Math]::Round($coveragePoints, 4)
        duplication = [Math]::Round($duplicationPoints, 4)
        efficiency = [Math]::Round($efficiencyPoints, 4)
        total = [Math]::Round($issuePoints + $behaviorPoints + $coveragePoints + $duplicationPoints + $efficiencyPoints, 4)
    }
    remainingMutationIds = @($remaining | ForEach-Object { $_.mutationId })
    resolvedMutationIds = @($resolved | ForEach-Object { $_.mutationId })
    newIssues = $newIssues
    scoredAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $result | ConvertTo-Json -Depth 100
}
else {
    $outputFull = Resolve-FullPath -Path $OutputPath
    New-Item -ItemType Directory -Force (Split-Path -Parent $outputFull) | Out-Null
    $result | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outputFull -Encoding UTF8
    Get-Content -LiteralPath $outputFull
}
