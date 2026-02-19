param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl,

    [string]$ReportDir = "Document/security",
    [string]$RulesFile = "scripts/phase4/zap-baseline-rules.tsv",
    [int]$Minutes = 5,
    [string]$Image = "ghcr.io/zaproxy/zaproxy:stable",
    [switch]$IgnoreWarnings,
    [string]$OutputPrefix = "zap-baseline"
)

$ErrorActionPreference = "Stop"

$fullReportDir = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Path $fullReportDir -Force | Out-Null

$fullRulesPath = [System.IO.Path]::GetFullPath($RulesFile)
if (-not (Test-Path $fullRulesPath)) {
    throw "Rules file not found: $fullRulesPath"
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("zap-baseline-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$rulesFileName = "zap-rules.tsv"
Copy-Item -Path $fullRulesPath -Destination (Join-Path $workDir $rulesFileName) -Force

$htmlName = "$OutputPrefix.html"
$jsonName = "$OutputPrefix.json"
$mdName = "$OutputPrefix.md"

$workMount = "$($workDir -replace '\\','/'):/zap/wrk"
$dockerTargetUrl = $TargetUrl
try {
    $parsedUrl = [Uri]$TargetUrl
    if ($parsedUrl.Host -eq "localhost" -or $parsedUrl.Host -eq "127.0.0.1") {
        $dockerTargetUrl = $TargetUrl -replace [Regex]::Escape($parsedUrl.Host), "host.docker.internal"
        Write-Host "Mapped localhost target for container access: $dockerTargetUrl"
    }
}
catch {
    throw "TargetUrl is invalid: $TargetUrl"
}

$args = @(
    "run", "--rm", "-t",
    "-v", $workMount,
    $Image,
    "zap-baseline.py",
    "-t", $dockerTargetUrl,
    "-r", $htmlName,
    "-J", $jsonName,
    "-w", $mdName,
    "-c", $rulesFileName,
    "-m", $Minutes.ToString()
)

if ($IgnoreWarnings) {
    $args += "-I"
}

Write-Host "Running ZAP baseline scan for: $TargetUrl"
Write-Host "Using rules file: $fullRulesPath"
$exitCode = 0
try {
    docker @args
    $exitCode = $LASTEXITCODE

    foreach ($file in @($htmlName, $jsonName, $mdName)) {
        $source = Join-Path $workDir $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination (Join-Path $fullReportDir $file) -Force
        }
    }
}
finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Reports generated in: $fullReportDir"

# ZAP baseline exit codes:
# 0 = pass, 1 = fail, 2 = warnings, 3+ = scan error.
if ($exitCode -eq 0) {
    if ($IgnoreWarnings) {
        Write-Host "ZAP baseline scan completed. Warnings (if any) were ignored for exit code (-IgnoreWarnings)."
    }
    else {
        Write-Host "ZAP baseline scan completed with no new warnings."
    }
}
elseif ($exitCode -eq 2) {
    Write-Host "ZAP baseline scan completed with warnings (exit code 2). See reports for details."
    if (-not $IgnoreWarnings) {
        exit 2
    }
}
else {
    throw "ZAP baseline scan failed with exit code $exitCode"
}

[pscustomobject]@{
    TargetUrl = $TargetUrl
    DockerTargetUrl = $dockerTargetUrl
    ExitCode = $exitCode
    HtmlReportPath = Join-Path $fullReportDir $htmlName
    JsonReportPath = Join-Path $fullReportDir $jsonName
    MarkdownReportPath = Join-Path $fullReportDir $mdName
}
