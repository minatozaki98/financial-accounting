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

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Resolve-JMeterContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUrl,
        [Parameter(Mandatory = $true)]
        [string]$Username,
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion,
        [Parameter(Mandatory = $true)]
        [int]$RequestedPeriodId,
        [Parameter(Mandatory = $true)]
        [int]$RequestedAccountId
    )

    $normalizedBaseUrl = $BaseUrl.TrimEnd("/")
    $commonHeaders = @{
        "X-Api-Version" = $ApiVersion
    }

    $loginPayload = @{
        username = $Username
        password = $Password
    } | ConvertTo-Json -Compress

    try {
        $loginResponse = Invoke-RestMethod -Method Post -Uri "$normalizedBaseUrl/auth/login" -Headers $commonHeaders -Body $loginPayload -ContentType "application/json"
    }
    catch {
        throw "Unable to authenticate for JMeter preflight at '$normalizedBaseUrl/auth/login'. $_"
    }

    $token = if (-not [string]::IsNullOrWhiteSpace([string]$loginResponse.accessToken)) {
        [string]$loginResponse.accessToken
    }
    else {
        [string]$loginResponse.AccessToken
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Login succeeded but no access token was returned for JMeter preflight."
    }

    $authHeaders = @{
        "X-Api-Version" = $ApiVersion
        "Authorization" = "Bearer $token"
    }

    try {
        $periodsResponse = Invoke-RestMethod -Method Get -Uri "$normalizedBaseUrl/periods" -Headers $authHeaders
    }
    catch {
        throw "Unable to fetch periods for JMeter preflight at '$normalizedBaseUrl/periods'. $_"
    }

    $periods = @($periodsResponse)
    if ($periods.Count -eq 0) {
        throw "No accounting periods are available. Seed data first using scripts/phase4/seed-test-data.ps1."
    }

    $resolvedPeriodId = $RequestedPeriodId
    $periodMatch = $periods | Where-Object {
        [int](Get-PropertyValue -Object $_ -Names @("periodId", "PeriodId")) -eq $RequestedPeriodId
    } | Select-Object -First 1

    if ($null -eq $periodMatch) {
        $openPeriod = $periods | Where-Object {
            -not [bool](Get-PropertyValue -Object $_ -Names @("isClosed", "IsClosed"))
        } | Sort-Object {
            [int](Get-PropertyValue -Object $_ -Names @("periodId", "PeriodId"))
        } -Descending | Select-Object -First 1

        $fallbackPeriod = if ($null -ne $openPeriod) {
            $openPeriod
        }
        else {
            $periods | Sort-Object {
                [int](Get-PropertyValue -Object $_ -Names @("periodId", "PeriodId"))
            } -Descending | Select-Object -First 1
        }

        $resolvedPeriodId = [int](Get-PropertyValue -Object $fallbackPeriod -Names @("periodId", "PeriodId"))
        Write-Host "Requested periodId '$RequestedPeriodId' was not found. Using periodId '$resolvedPeriodId'."
    }

    try {
        $accountsResponse = Invoke-RestMethod -Method Get -Uri "$normalizedBaseUrl/accounts?isActive=true" -Headers $authHeaders
    }
    catch {
        throw "Unable to fetch active accounts for JMeter preflight at '$normalizedBaseUrl/accounts'. $_"
    }

    $accounts = @($accountsResponse)
    if ($accounts.Count -eq 0) {
        throw "No active accounts are available. Seed data first using scripts/phase4/seed-test-data.ps1."
    }

    $resolvedAccountId = $RequestedAccountId
    $accountMatch = $accounts | Where-Object {
        [int](Get-PropertyValue -Object $_ -Names @("accountId", "AccountId")) -eq $RequestedAccountId
    } | Select-Object -First 1

    if ($null -eq $accountMatch) {
        $assetAccount = $accounts | Where-Object {
            [string]::Equals(
                [string](Get-PropertyValue -Object $_ -Names @("accountType", "AccountType")),
                "Asset",
                [System.StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object {
            [int](Get-PropertyValue -Object $_ -Names @("accountId", "AccountId"))
        } | Select-Object -First 1

        $fallbackAccount = if ($null -ne $assetAccount) {
            $assetAccount
        }
        else {
            $accounts | Sort-Object {
                [int](Get-PropertyValue -Object $_ -Names @("accountId", "AccountId"))
            } | Select-Object -First 1
        }

        $resolvedAccountId = [int](Get-PropertyValue -Object $fallbackAccount -Names @("accountId", "AccountId"))
        Write-Host "Requested accountId '$RequestedAccountId' was not found. Using accountId '$resolvedAccountId'."
    }

    return [pscustomobject]@{
        PeriodId = $resolvedPeriodId
        AccountId = $resolvedAccountId
    }
}

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

$resolvedContext = Resolve-JMeterContext `
    -BaseUrl $BaseUrl `
    -Username $Username `
    -Password $Password `
    -ApiVersion $ApiVersion `
    -RequestedPeriodId $PeriodId `
    -RequestedAccountId $AccountId

$resolvedPeriodId = [int]$resolvedContext.PeriodId
$resolvedAccountId = [int]$resolvedContext.AccountId

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
    "-JperiodId=$resolvedPeriodId",
    "-JaccountId=$resolvedAccountId",
    "-Jmode=$Mode",
    "-JcoreUsers=$CoreUsers",
    "-JcomplexUsers=$ComplexUsers",
    "-JcoreRampUp=$CoreRampUp",
    "-JcomplexRampUp=$ComplexRampUp",
    "-JcomplexLoops=$ComplexLoops"
)

Write-Host "Running JMeter test plan: $fullTestPlanPath"
Write-Host "users=$Users rampUp=$RampUp loops=$Loops mode=$Mode"
Write-Host "coreUsers=$CoreUsers complexUsers=$ComplexUsers"
Write-Host "periodId(requested/resolved)=$PeriodId/$resolvedPeriodId accountId(requested/resolved)=$AccountId/$resolvedAccountId"
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
    RequestedAccountId = $AccountId
    RequestedPeriodId = $PeriodId
    AccountId = $resolvedAccountId
    PeriodId = $resolvedPeriodId
}
