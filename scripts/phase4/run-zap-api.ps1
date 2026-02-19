param(
    [Parameter(Mandatory = $true)]
    [string]$OpenApiUrl,

    [string]$BaseUrl = "http://localhost:5296",
    [string]$Username = "admin",
    [string]$Password = "Admin@123",
    [string]$ApiVersion = "1.0",
    [string]$ReportDir = "Document/security",
    [string]$RulesFile = "scripts/phase4/zap-api-rules.tsv",
    [int]$Minutes = 10,
    [string]$Image = "ghcr.io/zaproxy/zaproxy:stable",
    [switch]$IgnoreWarnings,
    [string]$OutputPrefix = "zap-api"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

function Convert-ToDockerReachableUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $parsed = [Uri]$Url
    if ($parsed.Host -eq "localhost" -or $parsed.Host -eq "127.0.0.1") {
        return $Url -replace [Regex]::Escape($parsed.Host), "host.docker.internal"
    }

    return $Url
}

function Invoke-ExpectedStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [hashtable]$Headers,
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [int[]]$ExpectedStatusCodes
    )

    $statusCode = 0
    $httpClient = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), [Uri]$Uri)

    try {
        if ($null -ne $Headers) {
            foreach ($key in $Headers.Keys) {
                [void]$request.Headers.TryAddWithoutValidation([string]$key, [string]$Headers[$key])
            }
        }

        if (($Method -in @("POST", "PUT", "PATCH")) -and -not [string]::IsNullOrWhiteSpace($Body)) {
            $request.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, "application/json")
        }

        $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
    }
    finally {
        if ($response) {
            $response.Dispose()
        }

        $request.Dispose()
        $httpClient.Dispose()
    }

    if ($ExpectedStatusCodes -notcontains $statusCode) {
        throw "Unexpected status code for $Method $Uri. Expected: $($ExpectedStatusCodes -join ', ') Actual: $statusCode"
    }

    return $statusCode
}

function New-ProbeUserToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleName,
        [Parameter(Mandatory = $true)]
        [string]$TimestampId,
        [Parameter(Mandatory = $true)]
        [string]$LoginUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$CommonHeaders,
        [Parameter(Mandatory = $true)]
        [hashtable]$AdminHeaders,
        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $username = "zap-$($RoleName.ToLower())-$TimestampId"
    $email = "$username@local.invalid"

    $createPayload = @{
        username = $username
        email = $email
        password = $Password
        role = $RoleName
    } | ConvertTo-Json -Compress

    $createStatus = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/users" -Headers $AdminHeaders -Body $createPayload -ExpectedStatusCodes @(201)
    $loginPayload = @{
        username = $username
        password = $Password
    } | ConvertTo-Json -Compress

    $loginResponse = Invoke-RestMethod -Method Post -Uri $LoginUrl -Headers $CommonHeaders -Body $loginPayload -ContentType "application/json"
    $token = $loginResponse.accessToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        $token = $loginResponse.AccessToken
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Failed to obtain token for probe user role '$RoleName'."
    }

    return [pscustomobject]@{
        Username = $username
        Email = $email
        CreateStatus = $createStatus
        Token = $token
    }
}

$fullReportDir = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Path $fullReportDir -Force | Out-Null

$fullRulesPath = [System.IO.Path]::GetFullPath($RulesFile)
if (-not (Test-Path $fullRulesPath)) {
    throw "Rules file not found: $fullRulesPath"
}

$baseUri = [Uri]$BaseUrl
$openApiUri = [Uri]$OpenApiUrl
$normalizedBaseUrl = $baseUri.AbsoluteUri.TrimEnd("/")
$normalizedOpenApiUrl = $openApiUri.AbsoluteUri

$dockerBaseUrl = Convert-ToDockerReachableUrl -Url $normalizedBaseUrl
$dockerOpenApiUrl = Convert-ToDockerReachableUrl -Url $normalizedOpenApiUrl

$headers = @{
    "X-Api-Version" = $ApiVersion
}

$loginPayload = @{
    username = $Username
    password = $Password
} | ConvertTo-Json -Compress

$loginUrl = "$normalizedBaseUrl/auth/login"
Write-Host "Authenticating against: $loginUrl"
$loginResponse = Invoke-RestMethod -Method Post -Uri $loginUrl -Headers $headers -Body $loginPayload -ContentType "application/json"
$accessToken = $loginResponse.accessToken
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    $accessToken = $loginResponse.AccessToken
}

if ([string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Login succeeded but no access token was returned."
}

$adminHeaders = @{
    "X-Api-Version" = $ApiVersion
    "Authorization" = "Bearer $accessToken"
}

Write-Host "Running auth pre-checks (401/403 expectations)."
$unauthorizedChecks = [ordered]@{}
foreach ($route in @(
        "/users/me",
        "/accounts",
        "/periods",
        "/journal-entries",
        "/reports/trial-balance?periodId=202601",
        "/audit-logs?page=1&pageSize=10"
    )) {
    $unauthorizedChecks[$route] = Invoke-ExpectedStatus -Method GET -Uri "$normalizedBaseUrl$route" -Headers $headers -ExpectedStatusCodes @(401, 403)
}

$timestampId = Get-Date -Format "yyyyMMddHHmmssfff"
$probePassword = "User@12345!"

$userProbe = New-ProbeUserToken -RoleName "User" -TimestampId $timestampId -LoginUrl $loginUrl -CommonHeaders $headers -AdminHeaders $adminHeaders -Password $probePassword
$financeProbe = New-ProbeUserToken -RoleName "FinanceManager" -TimestampId $timestampId -LoginUrl $loginUrl -CommonHeaders $headers -AdminHeaders $adminHeaders -Password $probePassword
$auditorProbe = New-ProbeUserToken -RoleName "Auditor" -TimestampId $timestampId -LoginUrl $loginUrl -CommonHeaders $headers -AdminHeaders $adminHeaders -Password $probePassword

$userHeaders = @{
    "X-Api-Version" = $ApiVersion
    "Authorization" = "Bearer $($userProbe.Token)"
}
$financeHeaders = @{
    "X-Api-Version" = $ApiVersion
    "Authorization" = "Bearer $($financeProbe.Token)"
}
$auditorHeaders = @{
    "X-Api-Version" = $ApiVersion
    "Authorization" = "Bearer $($auditorProbe.Token)"
}

$forbiddenAccountPayload = @{
    accountCode = "ZAP-$timestampId"
    accountName = "ZAP Forbidden Check"
    accountType = "Asset"
    isActive = $true
} | ConvertTo-Json -Compress

$forbiddenPeriodPayload = @{
    periodId = 299901
    startDate = "2999-01-01"
    endDate = "2999-12-31"
} | ConvertTo-Json -Compress

$minimalJournalPayload = @{
    entryDate = "2026-01-15"
    lines = @(
        @{
            accountId = 1
            debit = 100
            credit = 0
        },
        @{
            accountId = 1
            debit = 0
            credit = 100
        }
    )
} | ConvertTo-Json -Compress

$rbacChecks = [ordered]@{}
$rbacChecks["User->POST /accounts"] = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/accounts" -Headers $userHeaders -Body $forbiddenAccountPayload -ExpectedStatusCodes @(403)
$rbacChecks["User->POST /periods"] = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/periods" -Headers $userHeaders -Body $forbiddenPeriodPayload -ExpectedStatusCodes @(403)
$rbacChecks["User->GET /reports/trial-balance"] = Invoke-ExpectedStatus -Method GET -Uri "$normalizedBaseUrl/reports/trial-balance?periodId=202601" -Headers $userHeaders -ExpectedStatusCodes @(403)
$rbacChecks["FinanceManager->POST /users"] = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/users" -Headers $financeHeaders -Body $forbiddenAccountPayload -ExpectedStatusCodes @(403)
$rbacChecks["FinanceManager->POST /accounts"] = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/accounts" -Headers $financeHeaders -Body $forbiddenAccountPayload -ExpectedStatusCodes @(403)
$rbacChecks["Auditor->POST /journal-entries"] = Invoke-ExpectedStatus -Method POST -Uri "$normalizedBaseUrl/journal-entries" -Headers $auditorHeaders -Body $minimalJournalPayload -ExpectedStatusCodes @(403)
$rbacChecks["Auditor->GET /audit-logs"] = Invoke-ExpectedStatus -Method GET -Uri "$normalizedBaseUrl/audit-logs?page=1&pageSize=10" -Headers $auditorHeaders -ExpectedStatusCodes @(200)

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("zap-api-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$rulesFileName = "zap-api-rules.tsv"
Copy-Item -Path $fullRulesPath -Destination (Join-Path $workDir $rulesFileName) -Force

$htmlName = "$OutputPrefix.html"
$jsonName = "$OutputPrefix.json"
$mdName = "$OutputPrefix.md"

$workMount = "$($workDir -replace '\\','/'):/zap/wrk"

# Use a replacer so ZAP requests include Authorization and X-Api-Version headers.
$tokenReplacement = "Bearer\\ $accessToken"
$zapOptions = @(
    "-config replacer.full_list(0).description=authHeader"
    "-config replacer.full_list(0).enabled=true"
    "-config replacer.full_list(0).matchtype=REQ_HEADER"
    "-config replacer.full_list(0).matchstr=Authorization"
    "-config replacer.full_list(0).replacement=$tokenReplacement"
    "-config replacer.full_list(1).description=apiVersionHeader"
    "-config replacer.full_list(1).enabled=true"
    "-config replacer.full_list(1).matchtype=REQ_HEADER"
    "-config replacer.full_list(1).matchstr=X-Api-Version"
    "-config replacer.full_list(1).replacement=$ApiVersion"
) -join " "

$args = @(
    "run", "--rm", "-t",
    "-v", $workMount,
    $Image,
    "zap-api-scan.py",
    "-t", $dockerOpenApiUrl,
    "-f", "openapi",
    "-r", $htmlName,
    "-J", $jsonName,
    "-w", $mdName,
    "-c", $rulesFileName,
    "-m", $Minutes.ToString(),
    "-z", $zapOptions
)

if ($IgnoreWarnings) {
    $args += "-I"
}

Write-Host "Running ZAP API scan for OpenAPI: $OpenApiUrl"
Write-Host "Docker OpenAPI URL: $dockerOpenApiUrl"
Write-Host "Docker Base URL: $dockerBaseUrl"
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

# ZAP API scan exit codes:
# 0 = pass, 1 = fail, 2 = warnings, 3+ = scan error.
if ($exitCode -eq 0) {
    if ($IgnoreWarnings) {
        Write-Host "ZAP API scan completed. Warnings (if any) were ignored for exit code (-IgnoreWarnings)."
    }
    else {
        Write-Host "ZAP API scan completed with no new warnings."
    }
}
elseif ($exitCode -eq 2) {
    Write-Host "ZAP API scan completed with warnings (exit code 2). See reports for details."
    if (-not $IgnoreWarnings) {
        exit 2
    }
}
else {
    throw "ZAP API scan failed with exit code $exitCode"
}

[pscustomobject]@{
    OpenApiUrl = $normalizedOpenApiUrl
    DockerOpenApiUrl = $dockerOpenApiUrl
    BaseUrl = $normalizedBaseUrl
    DockerBaseUrl = $dockerBaseUrl
    OutputPrefix = $OutputPrefix
    ExitCode = $exitCode
    AuthChecks = [pscustomobject]@{
        UnauthorizedChecks = [pscustomobject]$unauthorizedChecks
        CreatedProbeUsers = @(
            [pscustomobject]@{ Role = "User"; Username = $userProbe.Username; Status = $userProbe.CreateStatus },
            [pscustomobject]@{ Role = "FinanceManager"; Username = $financeProbe.Username; Status = $financeProbe.CreateStatus },
            [pscustomobject]@{ Role = "Auditor"; Username = $auditorProbe.Username; Status = $auditorProbe.CreateStatus }
        )
        RbacChecks = [pscustomobject]$rbacChecks
    }
    HtmlReportPath = Join-Path $fullReportDir $htmlName
    JsonReportPath = Join-Path $fullReportDir $jsonName
    MarkdownReportPath = Join-Path $fullReportDir $mdName
}
