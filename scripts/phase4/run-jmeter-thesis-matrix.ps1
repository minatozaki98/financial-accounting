param(
    [string]$BaseUrl = "http://localhost:5296",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$PeriodId = 202601,
    [int]$AccountId = 1,
    [string]$ResultsDir = "Document/performance",
    [string]$RunTag = ""
)

$ErrorActionPreference = "Stop"

$profileRunner = Join-Path $PSScriptRoot "run-jmeter-profile.ps1"
$runner = Join-Path $PSScriptRoot "run-jmeter.ps1"
$effectiveRunTag = if ([string]::IsNullOrWhiteSpace($RunTag)) { Get-Date -Format "yyyyMMdd-HHmmss" } else { $RunTag }

$profiles = @{}
foreach ($profile in @("50", "100", "500")) {
    Write-Host "Running JMeter profile $profile"
    $profiles[$profile] = & $profileRunner `
        -Profile $profile `
        -BaseUrl $BaseUrl `
        -Username $Username `
        -Password $Password `
        -ApiVersion $ApiVersion `
        -PeriodId $PeriodId `
        -AccountId $AccountId `
        -ResultsDir $ResultsDir `
        -OutputTag $effectiveRunTag
}

Write-Host "Running JMeter soak test"
$soak = & $runner `
    -TestPlanPath "Document/performance/jmeter/financial-api-soak-test.jmx" `
    -ResultsDir $ResultsDir `
    -BaseUrl $BaseUrl `
    -Username $Username `
    -Password $Password `
    -ApiVersion $ApiVersion `
    -PeriodId $PeriodId `
    -AccountId $AccountId `
    -Users 100 `
    -CoreUsers 100 `
    -ComplexUsers 30 `
    -RampUp 60 `
    -CoreRampUp 60 `
    -ComplexRampUp 60 `
    -Loops 180 `
    -ComplexLoops 180 `
    -Mode mixed `
    -OutputTag "$effectiveRunTag-soak"

Write-Host "Running JMeter spike test"
$spike = & $runner `
    -TestPlanPath "Document/performance/jmeter/financial-api-spike-test.jmx" `
    -ResultsDir $ResultsDir `
    -BaseUrl $BaseUrl `
    -Username $Username `
    -Password $Password `
    -ApiVersion $ApiVersion `
    -PeriodId $PeriodId `
    -AccountId $AccountId `
    -Users 500 `
    -CoreUsers 350 `
    -ComplexUsers 150 `
    -RampUp 30 `
    -CoreRampUp 30 `
    -ComplexRampUp 30 `
    -Loops 20 `
    -ComplexLoops 20 `
    -Mode mixed `
    -OutputTag "$effectiveRunTag-spike"

[pscustomobject]@{
    Profiles = [pscustomobject]@{
        "50" = $profiles["50"]
        "100" = $profiles["100"]
        "500" = $profiles["500"]
    }
    Soak = $soak
    Spike = $spike
    RunTag = $effectiveRunTag
}
