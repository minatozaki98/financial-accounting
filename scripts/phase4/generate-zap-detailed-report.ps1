param(
    [Parameter(Mandatory = $true)]
    [string]$JsonPath,

    [string]$OutputPath,
    [string]$Title = "ZAP Detailed Analysis Report"
)

$ErrorActionPreference = "Stop"

function Escape-Html {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Text)
}

function Html-ToPlainText {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return "" }

    $stripped = [regex]::Replace($Html, "<[^>]+>", " ")
    $decoded = [System.Net.WebUtility]::HtmlDecode($stripped)
    $normalized = [regex]::Replace($decoded, "\s+", " ").Trim()
    return $normalized
}

function RiskCode-ToLabel {
    param([int]$RiskCode)
    switch ($RiskCode) {
        3 { return "High" }
        2 { return "Medium" }
        1 { return "Low" }
        default { return "Informational" }
    }
}

function Severity-Rank {
    param([string]$Label)
    switch ($Label) {
        "High" { return 4 }
        "Medium" { return 3 }
        "Low" { return 2 }
        default { return 1 }
    }
}

$fullJsonPath = [System.IO.Path]::GetFullPath($JsonPath)
if (-not (Test-Path $fullJsonPath)) {
    throw "JSON report not found: $fullJsonPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $dir = Split-Path $fullJsonPath -Parent
    $name = [System.IO.Path]::GetFileNameWithoutExtension($fullJsonPath)
    $OutputPath = Join-Path $dir "$name-detailed.html"
}

$fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$raw = Get-Content -Path $fullJsonPath -Raw
$report = $raw | ConvertFrom-Json
$site = @($report.site | Select-Object -First 1)[0]
$alerts = @($site.alerts)
$insights = @($report.insights)

$riskSummary = [ordered]@{
    High = 0
    Medium = 0
    Low = 0
    Informational = 0
}

foreach ($alert in $alerts) {
    $label = RiskCode-ToLabel -RiskCode ([int]$alert.riskcode)
    $riskSummary[$label] = [int]$riskSummary[$label] + 1
}

$endpointMap = @{}
foreach ($alert in $alerts) {
    $severity = RiskCode-ToLabel -RiskCode ([int]$alert.riskcode)
    $severityRank = Severity-Rank -Label $severity
    foreach ($instance in @($alert.instances)) {
        if ($null -eq $instance) { continue }
        $uriText = [string]$instance.uri
        if ([string]::IsNullOrWhiteSpace($uriText)) { continue }

        try {
            $uri = [Uri]$uriText
            $endpoint = $uri.AbsolutePath
        }
        catch {
            $endpoint = $uriText
        }

        if (-not $endpointMap.ContainsKey($endpoint)) {
            $endpointMap[$endpoint] = [ordered]@{
                Endpoint = $endpoint
                Alerts = 0
                HighestSeverity = $severity
                HighestSeverityRank = $severityRank
            }
        }

        $endpointMap[$endpoint].Alerts = [int]$endpointMap[$endpoint].Alerts + 1
        if ($severityRank -gt [int]$endpointMap[$endpoint].HighestSeverityRank) {
            $endpointMap[$endpoint].HighestSeverity = $severity
            $endpointMap[$endpoint].HighestSeverityRank = $severityRank
        }
    }
}

$topEndpoints = @(
    $endpointMap.Values |
    Sort-Object @{ Expression = { $_.Alerts }; Descending = $true }, @{ Expression = { $_.HighestSeverityRank }; Descending = $true }, Endpoint |
    Select-Object -First 25
)

$generatedAt = if ($report.'@generated') { [string]$report.'@generated' } else { "" }
$createdUtc = if ($report.created) { [string]$report.created } else { "" }
$program = [string]$report.'@programName'
$version = [string]$report.'@version'
$siteName = if ($site.'@name') { [string]$site.'@name' } else { "" }
$scanHost = if ($site.'@host') { [string]$site.'@host' } else { "" }

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine("<!doctype html>")
$null = $sb.AppendLine("<html lang=""en"">")
$null = $sb.AppendLine("<head>")
$null = $sb.AppendLine("  <meta charset=""utf-8"">")
$null = $sb.AppendLine("  <meta name=""viewport"" content=""width=device-width, initial-scale=1"">")
$null = $sb.AppendLine("  <title>" + (Escape-Html $Title) + "</title>")
$null = $sb.AppendLine("  <style>")
$null = $sb.AppendLine("    body{font-family:Segoe UI,Arial,sans-serif;background:#f7f8fb;color:#1b1f2a;margin:0;padding:24px;}")
$null = $sb.AppendLine("    .wrap{max-width:1200px;margin:0 auto;}")
$null = $sb.AppendLine("    h1{margin:0 0 8px 0;font-size:28px;} h2{margin:28px 0 12px 0;font-size:20px;}")
$null = $sb.AppendLine("    .meta{background:#fff;border:1px solid #dde2ea;border-radius:10px;padding:14px 16px;line-height:1.6;}")
$null = $sb.AppendLine("    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-top:12px;}")
$null = $sb.AppendLine("    .card{background:#fff;border:1px solid #dde2ea;border-radius:10px;padding:12px 14px;}")
$null = $sb.AppendLine("    .num{font-size:28px;font-weight:700;margin-top:6px;}")
$null = $sb.AppendLine("    .high{border-left:5px solid #d62828;} .medium{border-left:5px solid #f77f00;} .low{border-left:5px solid #fcbf49;} .info{border-left:5px solid #457b9d;}")
$null = $sb.AppendLine("    table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #dde2ea;border-radius:10px;overflow:hidden;}")
$null = $sb.AppendLine("    th,td{padding:10px 12px;border-bottom:1px solid #edf0f4;text-align:left;vertical-align:top;font-size:14px;}")
$null = $sb.AppendLine("    th{background:#f2f5fa;font-weight:600;}")
$null = $sb.AppendLine("    tr:last-child td{border-bottom:none;}")
$null = $sb.AppendLine("    .pill{display:inline-block;border-radius:999px;padding:2px 9px;font-size:12px;font-weight:600;}")
$null = $sb.AppendLine("    .pill-high{background:#ffe5e5;color:#9b111e;} .pill-medium{background:#fff0da;color:#9a5a00;} .pill-low{background:#fff7dc;color:#7a6000;} .pill-info{background:#e9f2ff;color:#1f4a73;}")
$null = $sb.AppendLine("    details{background:#fff;border:1px solid #dde2ea;border-radius:10px;padding:10px 12px;margin-bottom:10px;}")
$null = $sb.AppendLine("    summary{cursor:pointer;font-weight:600;}")
$null = $sb.AppendLine("    .muted{color:#5a6475;font-size:13px;} .small{font-size:12px;color:#5a6475;} .code{font-family:Consolas,monospace;word-break:break-all;}")
$null = $sb.AppendLine("  </style>")
$null = $sb.AppendLine("</head>")
$null = $sb.AppendLine("<body>")
$null = $sb.AppendLine("<div class=""wrap"">")

$null = $sb.AppendLine("<h1>" + (Escape-Html $Title) + "</h1>")
$null = $sb.AppendLine("<div class=""meta"">")
$null = $sb.AppendLine("  <div><strong>Source JSON:</strong> <span class=""code"">" + (Escape-Html $fullJsonPath) + "</span></div>")
$null = $sb.AppendLine("  <div><strong>Tool:</strong> " + (Escape-Html "$program $version") + "</div>")
$null = $sb.AppendLine("  <div><strong>Site:</strong> " + (Escape-Html $siteName) + " <span class=""small"">(" + (Escape-Html $scanHost) + ")</span></div>")
$null = $sb.AppendLine("  <div><strong>Generated:</strong> " + (Escape-Html $generatedAt) + " <span class=""small"">created=" + (Escape-Html $createdUtc) + "</span></div>")
$null = $sb.AppendLine("</div>")

$null = $sb.AppendLine("<h2>Severity Summary</h2>")
$null = $sb.AppendLine("<div class=""grid"">")
$null = $sb.AppendLine("  <div class=""card high""><div>High Alerts</div><div class=""num"">" + $riskSummary.High + "</div></div>")
$null = $sb.AppendLine("  <div class=""card medium""><div>Medium Alerts</div><div class=""num"">" + $riskSummary.Medium + "</div></div>")
$null = $sb.AppendLine("  <div class=""card low""><div>Low Alerts</div><div class=""num"">" + $riskSummary.Low + "</div></div>")
$null = $sb.AppendLine("  <div class=""card info""><div>Informational Alerts</div><div class=""num"">" + $riskSummary.Informational + "</div></div>")
$null = $sb.AppendLine("  <div class=""card""><div>Total Alert Types</div><div class=""num"">" + $alerts.Count + "</div></div>")
$null = $sb.AppendLine("  <div class=""card""><div>Total Insights</div><div class=""num"">" + $insights.Count + "</div></div>")
$null = $sb.AppendLine("</div>")

$null = $sb.AppendLine("<h2>Top Affected Endpoints</h2>")
$null = $sb.AppendLine("<table>")
$null = $sb.AppendLine("<thead><tr><th>Endpoint</th><th>Alert Instances</th><th>Highest Severity</th></tr></thead>")
$null = $sb.AppendLine("<tbody>")
if ($topEndpoints.Count -eq 0) {
    $null = $sb.AppendLine("<tr><td colspan=""3"">No endpoint instances found.</td></tr>")
}
else {
    foreach ($row in $topEndpoints) {
        $sev = [string]$row.HighestSeverity
        $sevClass = switch ($sev) {
            "High" { "pill pill-high" }
            "Medium" { "pill pill-medium" }
            "Low" { "pill pill-low" }
            default { "pill pill-info" }
        }
        $null = $sb.AppendLine("<tr><td class=""code"">" + (Escape-Html ([string]$row.Endpoint)) + "</td><td>" + [int]$row.Alerts + "</td><td><span class=""" + $sevClass + """>" + (Escape-Html $sev) + "</span></td></tr>")
    }
}
$null = $sb.AppendLine("</tbody>")
$null = $sb.AppendLine("</table>")

$null = $sb.AppendLine("<h2>Alert Catalog</h2>")
$null = $sb.AppendLine("<table>")
$null = $sb.AppendLine("<thead><tr><th>Alert</th><th>Severity</th><th>Confidence</th><th>Instances</th><th>Rule ID</th><th>Systemic</th></tr></thead>")
$null = $sb.AppendLine("<tbody>")
foreach ($alert in ($alerts | Sort-Object @{ Expression = { [int]$_.riskcode }; Descending = $true }, alert)) {
    $sev = RiskCode-ToLabel -RiskCode ([int]$alert.riskcode)
    $sevClass = switch ($sev) {
        "High" { "pill pill-high" }
        "Medium" { "pill pill-medium" }
        "Low" { "pill pill-low" }
        default { "pill pill-info" }
    }
    $instancesCount = [int]$alert.count
    $null = $sb.AppendLine("<tr>")
    $null = $sb.AppendLine("<td>" + (Escape-Html ([string]$alert.alert)) + "</td>")
    $null = $sb.AppendLine("<td><span class=""" + $sevClass + """>" + (Escape-Html $sev) + "</span></td>")
    $null = $sb.AppendLine("<td>" + (Escape-Html ([string]$alert.confidence)) + "</td>")
    $null = $sb.AppendLine("<td>" + $instancesCount + "</td>")
    $null = $sb.AppendLine("<td class=""code"">" + (Escape-Html ([string]$alert.pluginid)) + "</td>")
    $null = $sb.AppendLine("<td>" + (Escape-Html ([string]$alert.systemic)) + "</td>")
    $null = $sb.AppendLine("</tr>")
}
$null = $sb.AppendLine("</tbody>")
$null = $sb.AppendLine("</table>")

$null = $sb.AppendLine("<h2>Alert Details</h2>")
foreach ($alert in ($alerts | Sort-Object @{ Expression = { [int]$_.riskcode }; Descending = $true }, alert)) {
    $sev = RiskCode-ToLabel -RiskCode ([int]$alert.riskcode)
    $desc = Html-ToPlainText -Html ([string]$alert.desc)
    $solution = Html-ToPlainText -Html ([string]$alert.solution)
    $reference = Html-ToPlainText -Html ([string]$alert.reference)
    $otherInfo = Html-ToPlainText -Html ([string]$alert.otherinfo)
    $instances = @($alert.instances)

    $null = $sb.AppendLine("<details>")
    $null = $sb.AppendLine("<summary>" + (Escape-Html ([string]$alert.alert)) + " <span class=""small"">(" + (Escape-Html $sev) + ", instances=" + (Escape-Html ([string]$alert.count)) + ", rule=" + (Escape-Html ([string]$alert.pluginid)) + ")</span></summary>")
    $null = $sb.AppendLine("<div class=""muted"" style=""margin-top:10px;"">")
    if (-not [string]::IsNullOrWhiteSpace($desc)) { $null = $sb.AppendLine("<p><strong>Description:</strong> " + (Escape-Html $desc) + "</p>") }
    if (-not [string]::IsNullOrWhiteSpace($solution)) { $null = $sb.AppendLine("<p><strong>Solution:</strong> " + (Escape-Html $solution) + "</p>") }
    if (-not [string]::IsNullOrWhiteSpace($reference)) { $null = $sb.AppendLine("<p><strong>Reference:</strong> " + (Escape-Html $reference) + "</p>") }
    if (-not [string]::IsNullOrWhiteSpace($otherInfo)) { $null = $sb.AppendLine("<p><strong>Other Info:</strong> " + (Escape-Html $otherInfo) + "</p>") }
    $null = $sb.AppendLine("</div>")

    $null = $sb.AppendLine("<table>")
    $null = $sb.AppendLine("<thead><tr><th>Method</th><th>URI</th><th>Param</th><th>Evidence</th></tr></thead><tbody>")
    if ($instances.Count -eq 0) {
        $null = $sb.AppendLine("<tr><td colspan=""4"">No concrete instances listed.</td></tr>")
    }
    else {
        foreach ($inst in $instances) {
            $null = $sb.AppendLine("<tr>")
            $null = $sb.AppendLine("<td>" + (Escape-Html ([string]$inst.method)) + "</td>")
            $null = $sb.AppendLine("<td class=""code"">" + (Escape-Html ([string]$inst.uri)) + "</td>")
            $null = $sb.AppendLine("<td>" + (Escape-Html ([string]$inst.param)) + "</td>")
            $null = $sb.AppendLine("<td class=""code"">" + (Escape-Html ([string]$inst.evidence)) + "</td>")
            $null = $sb.AppendLine("</tr>")
        }
    }
    $null = $sb.AppendLine("</tbody></table>")
    $null = $sb.AppendLine("</details>")
}

$null = $sb.AppendLine("<h2>Scan Insights</h2>")
$null = $sb.AppendLine("<table>")
$null = $sb.AppendLine("<thead><tr><th>Level</th><th>Reason</th><th>Description</th><th>Statistic</th></tr></thead><tbody>")
if ($insights.Count -eq 0) {
    $null = $sb.AppendLine("<tr><td colspan=""4"">No insights found.</td></tr>")
}
else {
    foreach ($insight in $insights) {
        $null = $sb.AppendLine("<tr><td>" + (Escape-Html ([string]$insight.level)) + "</td><td>" + (Escape-Html ([string]$insight.reason)) + "</td><td>" + (Escape-Html ([string]$insight.description)) + "</td><td>" + (Escape-Html ([string]$insight.statistic)) + "</td></tr>")
    }
}
$null = $sb.AppendLine("</tbody></table>")

$null = $sb.AppendLine("<p class=""small"" style=""margin-top:18px;"">Generated from " + (Escape-Html $fullJsonPath) + " at " + (Escape-Html (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) + ".</p>")
$null = $sb.AppendLine("</div></body></html>")

[System.IO.File]::WriteAllText($fullOutputPath, $sb.ToString(), [System.Text.Encoding]::UTF8)

[pscustomobject]@{
    JsonPath = $fullJsonPath
    OutputPath = $fullOutputPath
    AlertTypes = $alerts.Count
    High = $riskSummary.High
    Medium = $riskSummary.Medium
    Low = $riskSummary.Low
    Informational = $riskSummary.Informational
}
