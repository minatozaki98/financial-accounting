param(
    [Parameter(Mandatory = $true)]
    [string]$TestPlanPath,

    [string]$ResultsDir = "Document/performance",
    [string]$Image = "justb4/jmeter:5.5",
    [int]$Users = 50,
    [int]$RampUp = 30,
    [int]$Loops = 10,
    [string]$BaseUrl = "http://localhost:5296",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$PeriodId = 202601,
    [int]$AccountId = 1,
    [ValidateSet("core", "mixed")]
    [string]$Mode = "core",
    [int]$CoreUsers = -1,
    [int]$ComplexUsers = 0,
    [int]$CoreRampUp = -1,
    [int]$ComplexRampUp = -1,
    [int]$ComplexLoops = 5,
    [string]$OutputTag = ""
)

$ErrorActionPreference = "Stop"

$fullTestPlanPath = [System.IO.Path]::GetFullPath($TestPlanPath)
if (-not (Test-Path $fullTestPlanPath)) {
    throw "Test plan not found: $fullTestPlanPath"
}

$testDir = Split-Path $fullTestPlanPath -Parent
$testFile = Split-Path $fullTestPlanPath -Leaf

$fullResultsDir = [System.IO.Path]::GetFullPath($ResultsDir)
New-Item -ItemType Directory -Path $fullResultsDir -Force | Out-Null

if ($CoreUsers -lt 0) {
    $CoreUsers = $Users
}

if ($CoreRampUp -lt 0) {
    $CoreRampUp = $RampUp
}

if ($ComplexRampUp -lt 0) {
    $ComplexRampUp = $RampUp
}

$timestamp = if ([string]::IsNullOrWhiteSpace($OutputTag)) { Get-Date -Format "yyyyMMdd-HHmmss" } else { $OutputTag }
$jtlFile = "jmeter-$timestamp.jtl"
$htmlDir = "report-$timestamp"

$testMount = "$($testDir -replace '\\','/'):/tests"
$resultsMount = "$($fullResultsDir -replace '\\','/'):/results"

$dockerBaseUrl = $BaseUrl
try {
    $parsedUrl = [Uri]$BaseUrl
    if ($parsedUrl.Host -eq "localhost" -or $parsedUrl.Host -eq "127.0.0.1") {
        $dockerBaseUrl = $BaseUrl -replace [Regex]::Escape($parsedUrl.Host), "host.docker.internal"
        Write-Host "Mapped localhost baseUrl for container access: $dockerBaseUrl"
    }
}
catch {
    throw "BaseUrl is invalid: $BaseUrl"
}

$args = @(
    "run", "--rm",
    "-v", $testMount,
    "-v", $resultsMount,
    $Image,
    "-n",
    "-t", "/tests/$testFile",
    "-l", "/results/$jtlFile",
    "-e",
    "-o", "/results/$htmlDir",
    "-Jusers=$Users",
    "-Jrampup=$RampUp",
    "-Jloops=$Loops",
    "-JbaseUrl=$dockerBaseUrl",
    "-Jusername=$Username",
    "-Jpassword=$Password",
    "-JapiVersion=$ApiVersion",
    "-JperiodId=$PeriodId",
    "-JaccountId=$AccountId",
    "-Jmode=$Mode",
    "-JcoreUsers=$CoreUsers",
    "-JcomplexUsers=$ComplexUsers",
    "-JcoreRampUp=$CoreRampUp",
    "-JcomplexRampUp=$ComplexRampUp",
    "-JcomplexLoops=$ComplexLoops"
)

Write-Host "Running JMeter test plan: $fullTestPlanPath"
Write-Host "users=$Users rampUp=$RampUp loops=$Loops mode=$Mode"
Write-Host "coreUsers=$CoreUsers complexUsers=$ComplexUsers accountId=$AccountId"
docker @args
if ($LASTEXITCODE -ne 0) {
    throw "JMeter execution failed with exit code $LASTEXITCODE"
}

$jtlPath = Join-Path $fullResultsDir $jtlFile
$htmlReportPath = Join-Path $fullResultsDir $htmlDir
$statisticsPath = Join-Path $htmlReportPath "statistics.json"

Write-Host "JTL result: $jtlPath"
Write-Host "HTML report: $htmlReportPath"

[pscustomobject]@{
    Timestamp = $timestamp
    TestPlanPath = $fullTestPlanPath
    JtlPath = $jtlPath
    HtmlReportPath = $htmlReportPath
    StatisticsPath = $statisticsPath
    Users = $Users
    RampUp = $RampUp
    Loops = $Loops
    Mode = $Mode
    CoreUsers = $CoreUsers
    ComplexUsers = $ComplexUsers
    CoreRampUp = $CoreRampUp
    ComplexRampUp = $ComplexRampUp
    ComplexLoops = $ComplexLoops
    AccountId = $AccountId
    PeriodId = $PeriodId
}
