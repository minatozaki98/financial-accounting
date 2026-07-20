param(
    [Parameter(Mandatory = $true)]
    [string]$SonarToken,

    [string]$SonarUrl = "http://localhost:9000",
    [string]$ProjectKey = "financial-accounting-sonar-v2",
    [string]$ProjectVersion = "1.0",
    [string]$SourceRoot = ".",
    [string]$OutputDir = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/sonar"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function New-SonarTokenHeader {
    param([Parameter(Mandatory = $true)][string]$Token)

    $raw = "{0}:" -f $Token
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($raw))
    return @{ Authorization = "Basic $encoded" }
}

function Invoke-SonarGet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    $uri = "$($SonarUrl.TrimEnd('/'))$Path"
    try {
        return Invoke-RestMethod -Method GET -Uri $uri -Headers $Headers
    }
    catch {
        throw "SonarQube GET failed for $uri. $($_.Exception.Message)"
    }
}

function Get-ScannerVersionLine {
    $command = Get-Command "dotnet-sonarscanner" -ErrorAction SilentlyContinue
    if (-not $command) {
        return "unknown"
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $command.Source
    $startInfo.Arguments = "--version"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $lines = @($stdout -split "\r?\n") + @($stderr -split "\r?\n")
    $version = $lines | Where-Object { $_ -match "^SonarScanner for \.NET" } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($version)) {
        return "unknown"
    }

    return $version.Trim()
}

$sourceRootFull = Resolve-FullPath -Path $SourceRoot
$outputDirFull = Resolve-FullPath -Path $OutputDir
New-Item -ItemType Directory -Force $outputDirFull | Out-Null

$headers = New-SonarTokenHeader -Token $SonarToken
$metricKeys = @(
    "bugs",
    "vulnerabilities",
    "security_hotspots",
    "code_smells",
    "coverage",
    "duplicated_lines_density",
    "ncloc",
    "complexity",
    "cognitive_complexity",
    "reliability_rating",
    "security_rating",
    "sqale_rating"
) -join ","

$encodedProject = [Uri]::EscapeDataString($ProjectKey)
$measures = Invoke-SonarGet -Path "/api/measures/component?component=$encodedProject&metricKeys=$metricKeys" -Headers $headers
$qualityGate = Invoke-SonarGet -Path "/api/qualitygates/project_status?projectKey=$encodedProject" -Headers $headers

$allIssues = New-Object System.Collections.Generic.List[object]
$page = 1
$pageSize = 500
do {
    $issuesPath = "/api/issues/search?componentKeys=$encodedProject&resolved=false&additionalFields=_all&p=$page&ps=$pageSize"
    $response = Invoke-SonarGet -Path $issuesPath -Headers $headers
    foreach ($issue in @($response.issues)) {
        $allIssues.Add($issue)
    }
    if ($response.PSObject.Properties.Name -contains "paging" -and $null -ne $response.paging.total) {
        $total = [int]$response.paging.total
    }
    else {
        $total = [int]$response.total
    }

    if ($total -gt 10000) {
        throw "SonarQube returned $total open issues for project $ProjectKey. /api/issues/search exposes only the first 10000 results; reduce scan scope or challenge mutations before exporting evidence."
    }

    $page++
} while ($allIssues.Count -lt $total)

$issues = @($allIssues | ForEach-Object {
    [pscustomobject][ordered]@{
        key = $_.key
        rule = $_.rule
        component = $_.component
        project = $_.project
        line = $_.line
        message = $_.message
        type = $_.type
        severity = $_.severity
        impacts = $_.impacts
        effort = $_.effort
        status = $_.status
        resolution = $_.resolution
        creationDate = $_.creationDate
        updateDate = $_.updateDate
        tags = $_.tags
        textRange = $_.textRange
        flows = $_.flows
    }
})

$measureMap = [ordered]@{}
foreach ($measure in @($measures.component.measures)) {
    $measureMap[[string]$measure.metric] = [string]$measure.value
}

$sourceSha = ""
try {
    $sourceSha = (& git -C $sourceRootFull rev-parse HEAD).Trim()
}
catch {
    $sourceSha = "not-a-git-checkout"
}

$metadata = [ordered]@{
    projectKey = $ProjectKey
    projectVersion = $ProjectVersion
    sourceRoot = $sourceRootFull
    sourceSha = $sourceSha
    sonarUrl = $SonarUrl
    scannerVersion = Get-ScannerVersionLine
    exportedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}

$summary = [ordered]@{
    metadata = $metadata
    issueCount = $issues.Count
    issueCountByRule = @($issues | Group-Object rule | Sort-Object Count -Descending | ForEach-Object {
        [ordered]@{ rule = $_.Name; count = $_.Count }
    })
    issueCountByType = @($issues | Group-Object type | Sort-Object Name | ForEach-Object {
        [ordered]@{ type = $_.Name; count = $_.Count }
    })
    issueCountBySeverity = @($issues | Group-Object severity | Sort-Object Name | ForEach-Object {
        [ordered]@{ severity = $_.Name; count = $_.Count }
    })
    measures = $measureMap
    qualityGateStatus = $qualityGate.projectStatus.status
    ignoredConditions = $qualityGate.projectStatus.ignoredConditions
}

$issues | ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "issues-open.json") -Encoding UTF8
$measures | ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "measures-raw.json") -Encoding UTF8
$qualityGate | ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "quality-gate.json") -Encoding UTF8
$metadata | ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "metadata.json") -Encoding UTF8
$summary | ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "summary.json") -Encoding UTF8

Get-Content -LiteralPath (Join-Path $outputDirFull "summary.json")
