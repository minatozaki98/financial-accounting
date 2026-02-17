param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl,

    [string]$ReportDir = "Document/security",
    [string]$RulesFile = "scripts/phase4/zap-baseline-rules.tsv",
    [int]$Minutes = 5,
    [string]$Image = "ghcr.io/zaproxy/zaproxy:stable",
    [switch]$IgnoreWarnings
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
    "-r", "zap-baseline.html",
    "-J", "zap-baseline.json",
    "-w", "zap-baseline.md",
    "-c", $rulesFileName,
    "-m", $Minutes.ToString()
)

if ($IgnoreWarnings) {
    $args += "-I"
}

Write-Host "Running ZAP baseline scan for: $TargetUrl"
Write-Host "Using rules file: $fullRulesPath"
try {
    docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "ZAP baseline scan failed with exit code $LASTEXITCODE"
    }

    foreach ($file in @("zap-baseline.html", "zap-baseline.json", "zap-baseline.md")) {
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
