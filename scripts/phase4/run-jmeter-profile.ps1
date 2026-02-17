param(
    [ValidateSet("50", "100", "500")]
    [string]$Profile = "50",
    [string]$TestPlanPath = "Document/performance/jmeter/financial-api-load-test.jmx",
    [string]$BaseUrl = "http://localhost:5296",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$PeriodId = 202601,
    [string]$ResultsDir = "Document/performance"
)

$ErrorActionPreference = "Stop"

switch ($Profile) {
    "50" {
        $users = 50
        $rampUp = 30
        $loops = 10
    }
    "100" {
        $users = 100
        $rampUp = 60
        $loops = 10
    }
    "500" {
        $users = 500
        $rampUp = 180
        $loops = 5
    }
    default {
        throw "Unsupported profile: $Profile"
    }
}

$runner = Join-Path $PSScriptRoot "run-jmeter.ps1"
$params = @{
    TestPlanPath = $TestPlanPath
    ResultsDir = $ResultsDir
    Users = $users
    RampUp = $rampUp
    Loops = $loops
    BaseUrl = $BaseUrl
    Username = $Username
    Password = $Password
    ApiVersion = $ApiVersion
    PeriodId = $PeriodId
}

& $runner @params
