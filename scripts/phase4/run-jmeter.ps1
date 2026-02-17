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
    [int]$PeriodId = 202601
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

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jtlFile = "jmeter-$timestamp.jtl"
$htmlDir = "report-$timestamp"

$testMount = "$($testDir -replace '\\','/'):/tests"
$resultsMount = "$($fullResultsDir -replace '\\','/'):/results"

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
    "-JbaseUrl=$BaseUrl",
    "-Jusername=$Username",
    "-Jpassword=$Password",
    "-JapiVersion=$ApiVersion",
    "-JperiodId=$PeriodId"
)

Write-Host "Running JMeter test plan: $fullTestPlanPath"
Write-Host "users=$Users rampUp=$RampUp loops=$Loops"
docker @args
if ($LASTEXITCODE -ne 0) {
    throw "JMeter execution failed with exit code $LASTEXITCODE"
}

Write-Host "JTL result: $fullResultsDir\\$jtlFile"
Write-Host "HTML report: $fullResultsDir\\$htmlDir"
