param(
    [ValidateSet("50", "100", "500")]
    [string]$Profile = "50",
    [string]$TestPlanPath = "Document/performance/jmeter/financial-api-load-test.jmx",
    [string]$BaseUrl = "http://localhost:5296",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [int]$PeriodId = 202601,
    [int]$AccountId = 1,
    [string]$ResultsDir = "Document/performance",
    [string]$OutputTag = ""
)

$ErrorActionPreference = "Stop"

switch ($Profile) {
    "50" {
        $users = 50
        $rampUp = 30
        $loops = 10
        $mode = "core"
        $coreUsers = 50
        $complexUsers = 0
        $complexLoops = 5
    }
    "100" {
        $users = 100
        $rampUp = 60
        $loops = 10
        $mode = "mixed"
        $coreUsers = 70
        $complexUsers = 30
        $complexLoops = 10
    }
    "500" {
        $users = 500
        $rampUp = 180
        $loops = 5
        $mode = "mixed"
        $coreUsers = 350
        $complexUsers = 150
        $complexLoops = 5
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
    AccountId = $AccountId
    Mode = $mode
    CoreUsers = $coreUsers
    ComplexUsers = $complexUsers
    CoreRampUp = $rampUp
    ComplexRampUp = $rampUp
    ComplexLoops = $complexLoops
    OutputTag = if ([string]::IsNullOrWhiteSpace($OutputTag)) { "" } else { "$OutputTag-p$Profile" }
}

$result = & $runner @params
if ($null -eq $result) {
    throw "JMeter runner did not return a result object."
}

$result | Add-Member -MemberType NoteProperty -Name Profile -Value $Profile -Force
$result
