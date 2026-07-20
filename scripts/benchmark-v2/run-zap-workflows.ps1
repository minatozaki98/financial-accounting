param(
    [string]$BaseUrl = "http://localhost:5296",
    [string]$OpenApiUrl = "http://localhost:5296/swagger/v1/swagger.json",
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "Admin@123",
    [string]$ApiVersion = "1.0",
    [string]$ValidCsvPath = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/fixtures/journal-import/journal-import-valid-10.csv",
    [string]$OutputDir = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/zap",
    [string]$RulesFile = "scripts/phase4/zap-api-rules.tsv",
    [string]$Image = "ghcr.io/zaproxy/zaproxy:stable",
    [int]$Minutes = 10,
    [string]$OutputPrefix = "zap-workflow-v2",
    [switch]$SkipZapScan,
    [switch]$SafeMode,
    [switch]$IgnoreWarnings
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Convert-ToDockerReachableUrl {
    param([Parameter(Mandatory = $true)][string]$Url)

    $parsed = [Uri]$Url
    if ($parsed.Host -eq "localhost" -or $parsed.Host -eq "127.0.0.1") {
        return $Url -replace [Regex]::Escape($parsed.Host), "host.docker.internal"
    }

    return $Url
}

function ConvertTo-ItemArray {
    param($Value)

    return @(
        if ($null -eq $Value) {
            return
        }
        elseif ($Value -is [System.Array]) {
            foreach ($item in $Value) {
                $item
            }
        }
        else {
            $Value
        }
    )
}

function ConvertTo-NormalizedRoute {
    param([Parameter(Mandatory = $true)][string]$Uri)

    $path = ([Uri]$Uri).AbsolutePath.TrimEnd("/")
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "/"
    }

    $path = $path -replace "/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", "/{guid}"
    $path = $path -replace "/\d+", "/{id}"
    return $path
}

function New-RoleHeaders {
    param(
        [string]$Token = ""
    )

    $headers = @{
        "X-Api-Version" = $ApiVersion
    }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers["Authorization"] = "Bearer $Token"
    }

    return $headers
}

function Get-JsonValue {
    param(
        $Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }

    $property = $Object.PSObject.Properties |
        Where-Object { [string]::Equals($_.Name, $Name, [StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1
    if ($property) {
        return $property.Value
    }

    return $null
}

$baseUri = [Uri]$BaseUrl
$openApiUri = [Uri]$OpenApiUrl
$normalizedBaseUrl = $baseUri.AbsoluteUri.TrimEnd("/")
$normalizedOpenApiUrl = $openApiUri.AbsoluteUri
$outputDirFull = Resolve-FullPath -Path $OutputDir
$validCsvFull = Resolve-FullPath -Path $ValidCsvPath
$rulesFileFull = Resolve-FullPath -Path $RulesFile

if (-not (Test-Path -LiteralPath $validCsvFull)) {
    throw "ValidCsvPath was not found: $validCsvFull"
}
if (-not $SkipZapScan -and -not (Test-Path -LiteralPath $rulesFileFull)) {
    throw "RulesFile was not found: $rulesFileFull"
}

New-Item -ItemType Directory -Force $outputDirFull | Out-Null

$coverage = New-Object System.Collections.Generic.List[object]

function Add-Coverage {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][int]$RequestStatus,
        [Parameter(Mandatory = $true)][int[]]$ExpectedStatus,
        [string]$ContentType = "",
        [Parameter(Mandatory = $true)][string]$ProbeKind,
        [bool]$BusinessStateValid = $false,
        [string]$Notes = ""
    )

    $coverage.Add([pscustomobject][ordered]@{
        method = $Method
        route = ConvertTo-NormalizedRoute -Uri $Uri
        role = $Role
        requestStatus = $RequestStatus
        expectedStatus = $ExpectedStatus
        contentType = $ContentType
        probeKind = $ProbeKind
        businessStateValid = $BusinessStateValid
        notes = $Notes
    })
}

function Invoke-ApiRequest {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Headers,
        [object]$Body = $null,
        [Parameter(Mandatory = $true)][int[]]$ExpectedStatus,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$ProbeKind,
        [bool]$BusinessStateValid = $false,
        [string]$Notes = ""
    )

    $uri = if ($Path.StartsWith("http", [StringComparison]::OrdinalIgnoreCase)) {
        $Path
    }
    else {
        "$normalizedBaseUrl/$($Path.TrimStart('/'))"
    }

    $client = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), [Uri]$uri)
    try {
        foreach ($key in $Headers.Keys) {
            [void]$request.Headers.TryAddWithoutValidation([string]$key, [string]$Headers[$key])
        }

        if ($null -ne $Body -and $Method -in @("POST", "PUT", "PATCH")) {
            $json = $Body | ConvertTo-Json -Depth 20 -Compress
            $request.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, "application/json")
        }

        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $status = [int]$response.StatusCode
        $contentType = if ($response.Content.Headers.ContentType) { [string]$response.Content.Headers.ContentType } else { "" }
        $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        Add-Coverage -Method $Method -Uri $uri -Role $Role -RequestStatus $status -ExpectedStatus $ExpectedStatus -ContentType $contentType -ProbeKind $ProbeKind -BusinessStateValid:$BusinessStateValid -Notes $Notes

        if ($ExpectedStatus -notcontains $status) {
            throw "Unexpected status for $Method $uri. Expected $($ExpectedStatus -join ',') but got $status. Body: $raw"
        }

        $jsonBody = $null
        if (-not [string]::IsNullOrWhiteSpace($raw) -and $contentType -match "json") {
            $jsonBody = $raw | ConvertFrom-Json
        }

        return [pscustomobject]@{
            status = $status
            contentType = $contentType
            raw = $raw
            json = $jsonBody
        }
    }
    finally {
        if ($response) {
            $response.Dispose()
        }
        $request.Dispose()
        $client.Dispose()
    }
}

function Invoke-MultipartUpload {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Headers,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$IdempotencyKey,
        [Parameter(Mandatory = $true)][bool]$Atomic,
        [Parameter(Mandatory = $true)][int[]]$ExpectedStatus,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][string]$ProbeKind,
        [bool]$BusinessStateValid = $false,
        [string]$Notes = ""
    )

    $uri = "$normalizedBaseUrl/$($Path.TrimStart('/'))"
    $client = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, [Uri]$uri)
    $multipart = [System.Net.Http.MultipartFormDataContent]::new()
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/csv")
    try {
        foreach ($key in $Headers.Keys) {
            [void]$request.Headers.TryAddWithoutValidation([string]$key, [string]$Headers[$key])
        }

        $multipart.Add($fileContent, "File", [System.IO.Path]::GetFileName($FilePath))
        $multipart.Add([System.Net.Http.StringContent]::new($IdempotencyKey), "IdempotencyKey")
        $multipart.Add([System.Net.Http.StringContent]::new($Atomic.ToString().ToLowerInvariant()), "Atomic")
        $request.Content = $multipart

        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $status = [int]$response.StatusCode
        $contentType = if ($response.Content.Headers.ContentType) { [string]$response.Content.Headers.ContentType } else { "" }
        $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        Add-Coverage -Method "POST" -Uri $uri -Role $Role -RequestStatus $status -ExpectedStatus $ExpectedStatus -ContentType $contentType -ProbeKind $ProbeKind -BusinessStateValid:$BusinessStateValid -Notes $Notes

        if ($ExpectedStatus -notcontains $status) {
            throw "Unexpected status for multipart POST $uri. Expected $($ExpectedStatus -join ',') but got $status. Body: $raw"
        }

        $jsonBody = $null
        if (-not [string]::IsNullOrWhiteSpace($raw) -and $contentType -match "json") {
            $jsonBody = $raw | ConvertFrom-Json
        }

        return [pscustomobject]@{
            status = $status
            contentType = $contentType
            raw = $raw
            json = $jsonBody
        }
    }
    finally {
        if ($response) {
            $response.Dispose()
        }
        $multipart.Dispose()
        $request.Dispose()
        $client.Dispose()
    }
}

function Invoke-Login {
    param(
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][string]$RoleLabel
    )

    $response = Invoke-ApiRequest `
        -Method POST `
        -Path "/auth/login" `
        -Headers (New-RoleHeaders) `
        -Body @{ username = $Username; password = $Password } `
        -ExpectedStatus @(200) `
        -Role $RoleLabel `
        -ProbeKind "authentication" `
        -BusinessStateValid:$true

    $token = Get-JsonValue -Object $response.json -Name "accessToken"
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Login response did not contain an access token for $Username."
    }

    return [string]$token
}

function New-ProbeRoleToken {
    param(
        [Parameter(Mandatory = $true)][string]$RoleName,
        [Parameter(Mandatory = $true)][string]$AdminToken,
        [Parameter(Mandatory = $true)][string]$RunId
    )

    $username = "zapv2-$($RoleName.ToLowerInvariant())-$RunId"
    $password = "User@12345!"
    $createBody = @{
        username = $username
        email = "$username@local.invalid"
        password = $password
        role = $RoleName
    }

    [void](Invoke-ApiRequest `
        -Method POST `
        -Path "/users" `
        -Headers (New-RoleHeaders -Token $AdminToken) `
        -Body $createBody `
        -ExpectedStatus @(201) `
        -Role "Admin" `
        -ProbeKind "workflow-setup" `
        -BusinessStateValid:$true `
        -Notes "Created $RoleName probe user")

    $token = Invoke-Login -Username $username -Password $password -RoleLabel $RoleName
    return [pscustomobject]@{
        username = $username
        role = $RoleName
        token = $token
    }
}

function Export-VerifiedZapAlerts {
    param(
        [Parameter(Mandatory = $true)][string]$ZapJsonPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $ZapJsonPath)) {
        "[]" | Set-Content -LiteralPath $OutputPath -Encoding UTF8
        return @()
    }

    $zap = Get-Content -LiteralPath $ZapJsonPath -Raw | ConvertFrom-Json
    $businessRoutePrefixes = @(
        "/periods",
        "/journal-imports",
        "/reconciliations",
        "/journal-entries",
        "/accounts",
        "/reports",
        "/audit-logs",
        "/users/me"
    )

    $verified = New-Object System.Collections.Generic.List[object]
    $excludedAlertIds = @("100000")
    foreach ($site in (ConvertTo-ItemArray $zap.site)) {
        foreach ($alert in (ConvertTo-ItemArray $site.alerts)) {
            $alertId = [string]$alert.pluginid
            if ($excludedAlertIds -contains $alertId) {
                continue
            }

            foreach ($instance in (ConvertTo-ItemArray $alert.instances)) {
                $uri = [string]$instance.uri
                if ([string]::IsNullOrWhiteSpace($uri)) {
                    continue
                }

                $path = ([Uri]$uri).AbsolutePath
                $isBusiness = $false
                foreach ($prefix in $businessRoutePrefixes) {
                    if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                        $isBusiness = $true
                        break
                    }
                }

                if (-not $isBusiness) {
                    continue
                }

                $riskDescription = [string]$alert.riskdesc
                $risk = ($riskDescription -split "\s+\(", 2)[0]
                $verified.Add([pscustomobject][ordered]@{
                    alertId = $alertId
                    alertRef = [string]$alert.alertRef
                    name = [string]$alert.alert
                    risk = $risk
                    riskDescription = $riskDescription
                    confidence = [string]$alert.confidence
                    method = [string]$instance.method
                    uri = $uri
                    normalizedRoute = ConvertTo-NormalizedRoute -Uri $uri
                    evidence = [string]$instance.evidence
                    param = [string]$instance.param
                })
            }
        }
    }

    $verifiedArray = @($verified.ToArray())
    if ($verifiedArray.Count -eq 0) {
        "[]" | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }
    else {
        $verifiedArray | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    }

    return $verifiedArray
}

$runId = Get-Date -Format "yyyyMMddHHmmssfff"
$adminToken = Invoke-Login -Username $AdminUsername -Password $AdminPassword -RoleLabel "Admin"
$financeProbe = New-ProbeRoleToken -RoleName "FinanceManager" -AdminToken $adminToken -RunId $runId
$userProbe = New-ProbeRoleToken -RoleName "User" -AdminToken $adminToken -RunId $runId
$auditorProbe = New-ProbeRoleToken -RoleName "Auditor" -AdminToken $adminToken -RunId $runId

$adminHeaders = New-RoleHeaders -Token $adminToken
$financeHeaders = New-RoleHeaders -Token $financeProbe.token
$userHeaders = New-RoleHeaders -Token $userProbe.token
$auditorHeaders = New-RoleHeaders -Token $auditorProbe.token
$anonymousHeaders = New-RoleHeaders

[void](Invoke-ApiRequest -Method GET -Path "/users/me" -Headers $adminHeaders -ExpectedStatus @(200) -Role "Admin" -ProbeKind "workflow-setup" -BusinessStateValid:$true)
[void](Invoke-ApiRequest -Method GET -Path "/users/me" -Headers $financeHeaders -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "workflow-setup" -BusinessStateValid:$true)
[void](Invoke-ApiRequest -Method GET -Path "/users/me" -Headers $userHeaders -ExpectedStatus @(200) -Role "User" -ProbeKind "workflow-setup" -BusinessStateValid:$true)
[void](Invoke-ApiRequest -Method GET -Path "/users/me" -Headers $auditorHeaders -ExpectedStatus @(200) -Role "Auditor" -ProbeKind "workflow-setup" -BusinessStateValid:$true)

$accountsResponse = Invoke-ApiRequest -Method GET -Path "/accounts?isActive=true" -Headers $adminHeaders -ExpectedStatus @(200) -Role "Admin" -ProbeKind "workflow-setup" -BusinessStateValid:$true
$accounts = ConvertTo-ItemArray $accountsResponse.json
$assetAccount = $accounts | Where-Object { [string]::Equals($_.accountType, "Asset", [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
$offsetAccount = $accounts | Where-Object { -not [string]::Equals($_.accountType, "Asset", [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
if ($null -eq $assetAccount -or $null -eq $offsetAccount) {
    throw "Could not select asset and offset accounts from /accounts response."
}

$periodsResponse = Invoke-ApiRequest -Method GET -Path "/periods" -Headers $financeHeaders -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "workflow-setup" -BusinessStateValid:$true
$periods = ConvertTo-ItemArray $periodsResponse.json
$closePeriod = $periods |
    Where-Object { -not $_.isClosed -and [int]$_.periodId -ge 202701 } |
    Sort-Object periodId |
    Select-Object -First 1
if ($null -eq $closePeriod) {
    throw "No open benchmark period >= 202701 was found for close workflow."
}

$preview = Invoke-ApiRequest `
    -Method GET `
    -Path "/periods/$($closePeriod.periodId)/close-preview" `
    -Headers $financeHeaders `
    -ExpectedStatus @(200) `
    -Role "FinanceManager" `
    -ProbeKind "business-workflow" `
    -BusinessStateValid:$true `
    -Notes "Valid period-close preview"

$closeRequestId = [Guid]::NewGuid()
$closeBody = @{
    requestId = $closeRequestId
    expectedVersion = [int](Get-JsonValue -Object $preview.json -Name "version")
}
$closeResult = Invoke-ApiRequest `
    -Method POST `
    -Path "/periods/$($closePeriod.periodId)/close" `
    -Headers $financeHeaders `
    -Body $closeBody `
    -ExpectedStatus @(200) `
    -Role "FinanceManager" `
    -ProbeKind "business-workflow" `
    -BusinessStateValid:$true `
    -Notes "Valid period-close execution"
[void](Invoke-ApiRequest `
    -Method POST `
    -Path "/periods/$($closePeriod.periodId)/close" `
    -Headers $financeHeaders `
    -Body $closeBody `
    -ExpectedStatus @(200) `
    -Role "FinanceManager" `
    -ProbeKind "business-workflow" `
    -BusinessStateValid:$true `
    -Notes "Idempotent period-close replay")

$validImport = Invoke-MultipartUpload `
    -Path "/journal-imports/validate" `
    -Headers $financeHeaders `
    -FilePath $validCsvFull `
    -IdempotencyKey "zapv2-valid-$runId" `
    -Atomic $true `
    -ExpectedStatus @(200) `
    -Role "FinanceManager" `
    -ProbeKind "business-workflow" `
    -BusinessStateValid:$true `
    -Notes "Valid multipart journal import"

$validImportId = [string](Get-JsonValue -Object $validImport.json -Name "importId")
if ([string]::IsNullOrWhiteSpace($validImportId)) {
    throw "Journal import validation response did not include importId."
}
[void](Invoke-ApiRequest -Method POST -Path "/journal-imports/$validImportId/commit" -Headers $financeHeaders -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Commit valid journal import")
[void](Invoke-ApiRequest -Method POST -Path "/journal-imports/$validImportId/commit" -Headers $financeHeaders -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Replay valid journal import commit")

$invalidCsvPath = Join-Path $outputDirFull "invalid-journal-import-$runId.csv"
[System.IO.File]::WriteAllText(
    $invalidCsvPath,
    "EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit`r`n2026-04-01,ZAP-BAD-$runId,Invalid import row,NO_SUCH_ACCOUNT,10.00,0.00`r`n",
    [System.Text.UTF8Encoding]::new($false))
$invalidImport = Invoke-MultipartUpload `
    -Path "/journal-imports/validate" `
    -Headers $financeHeaders `
    -FilePath $invalidCsvPath `
    -IdempotencyKey "zapv2-invalid-$runId" `
    -Atomic $true `
    -ExpectedStatus @(200) `
    -Role "FinanceManager" `
    -ProbeKind "business-workflow" `
    -BusinessStateValid:$true `
    -Notes "Invalid atomic multipart journal import validation"

$invalidImportId = [string](Get-JsonValue -Object $invalidImport.json -Name "importId")
if (-not [string]::IsNullOrWhiteSpace($invalidImportId)) {
    [void](Invoke-ApiRequest -Method POST -Path "/journal-imports/$invalidImportId/commit" -Headers $financeHeaders -ExpectedStatus @(400, 409) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Invalid atomic import commit rejection")
}

$reference = "ZAPV2-$runId"
$journalBody = @{
    entryDate = "2026-06-15"
    description = "ZAP v2 reconciliation setup"
    referenceNo = $reference
    lines = @(
        @{
            accountId = [int]$assetAccount.accountId
            lineDescription = "Bank debit"
            debit = 123.45
            credit = 0
        },
        @{
            accountId = [int]$offsetAccount.accountId
            lineDescription = "Offset credit"
            debit = 0
            credit = 123.45
        }
    )
}
$journal = Invoke-ApiRequest -Method POST -Path "/journal-entries" -Headers $financeHeaders -Body $journalBody -ExpectedStatus @(201) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Create reconciliation setup draft"
$journalId = [long](Get-JsonValue -Object $journal.json -Name "journalEntryId")
[void](Invoke-ApiRequest -Method POST -Path "/journal-entries/$journalId/post" -Headers $financeHeaders -ExpectedStatus @(204) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Post reconciliation setup journal entry")

$reconciliationBody = @{
    periodId = 202601
    bankAccountId = [int]$assetAccount.accountId
    dateFrom = "2026-01-01"
    dateTo = "2026-12-31"
    transactions = @(
        @{
            transactionDate = "2026-06-15"
            amount = 123.45
            referenceNo = $reference
            description = "ZAP v2 exact bank transaction"
        }
    )
}
$reconciliation = Invoke-ApiRequest -Method POST -Path "/reconciliations" -Headers $financeHeaders -Body $reconciliationBody -ExpectedStatus @(201) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Create valid reconciliation"
$reconciliationId = [string](Get-JsonValue -Object $reconciliation.json -Name "reconciliationId")
$match = Invoke-ApiRequest -Method POST -Path "/reconciliations/$reconciliationId/auto-match" -Headers $financeHeaders -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Auto-match valid reconciliation"
[void](Invoke-ApiRequest -Method GET -Path "/reconciliations/$reconciliationId/exceptions" -Headers $auditorHeaders -ExpectedStatus @(200) -Role "Auditor" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Auditor exception listing")
$finalizeBody = @{
    requestId = [Guid]::NewGuid()
    expectedVersion = [int](Get-JsonValue -Object $match.json -Name "version")
}
[void](Invoke-ApiRequest -Method POST -Path "/reconciliations/$reconciliationId/finalize" -Headers $financeHeaders -Body $finalizeBody -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Finalize valid reconciliation")
[void](Invoke-ApiRequest -Method POST -Path "/reconciliations/$reconciliationId/finalize" -Headers $financeHeaders -Body $finalizeBody -ExpectedStatus @(200) -Role "FinanceManager" -ProbeKind "business-workflow" -BusinessStateValid:$true -Notes "Replay reconciliation finalization")

[void](Invoke-ApiRequest -Method GET -Path "/periods" -Headers $anonymousHeaders -ExpectedStatus @(401) -Role "Anonymous" -ProbeKind "authorization-boundary" -BusinessStateValid:$false -Notes "Unauthenticated periods probe")
[void](Invoke-ApiRequest -Method POST -Path "/journal-imports/validate" -Headers $userHeaders -ExpectedStatus @(403) -Role "User" -ProbeKind "authorization-boundary" -BusinessStateValid:$false -Notes "Forbidden import validation role")
[void](Invoke-ApiRequest -Method POST -Path "/reconciliations" -Headers $auditorHeaders -Body $reconciliationBody -ExpectedStatus @(403) -Role "Auditor" -ProbeKind "authorization-boundary" -BusinessStateValid:$false -Notes "Forbidden reconciliation create role")
[void](Invoke-ApiRequest -Method GET -Path "/reconciliations/$reconciliationId/exceptions" -Headers $userHeaders -ExpectedStatus @(403) -Role "User" -ProbeKind "authorization-boundary" -BusinessStateValid:$false -Notes "Forbidden exception listing role")
[void](Invoke-ApiRequest -Method POST -Path "/periods/$($closePeriod.periodId)/close" -Headers $userHeaders -Body $closeBody -ExpectedStatus @(403) -Role "User" -ProbeKind "authorization-boundary" -BusinessStateValid:$false -Notes "Forbidden period-close role")

$coveragePath = Join-Path $outputDirFull "endpoint-coverage.json"
$coverageSummaryPath = Join-Path $outputDirFull "endpoint-coverage-summary.json"
$coverage | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $coveragePath -Encoding UTF8

$requiredBusinessRoutes = @(
    "GET /periods/{id}/close-preview",
    "POST /periods/{id}/close",
    "POST /journal-imports/validate",
    "POST /journal-imports/{guid}/commit",
    "POST /journal-entries",
    "POST /journal-entries/{id}/post",
    "POST /reconciliations",
    "POST /reconciliations/{guid}/auto-match",
    "GET /reconciliations/{guid}/exceptions",
    "POST /reconciliations/{guid}/finalize"
)

$coveredBusiness = @($coverage | Where-Object { $_.probeKind -eq "business-workflow" -and $_.businessStateValid })
$coveredKeys = @{}
foreach ($item in $coveredBusiness) {
    $coveredKeys["$($item.method) $($item.route)"] = $true
}
$missingRoutes = @($requiredBusinessRoutes | Where-Object { -not $coveredKeys.ContainsKey($_) })
$failedCoverage = @($coverage | Where-Object { $_.expectedStatus -notcontains $_.requestStatus })

$coverageSummary = [pscustomobject][ordered]@{
    baseUrl = $normalizedBaseUrl
    openApiUrl = $normalizedOpenApiUrl
    runId = $runId
    totalProbeCount = $coverage.Count
    validBusinessProbeCount = $coveredBusiness.Count
    authorizationBoundaryProbeCount = @($coverage | Where-Object probeKind -eq "authorization-boundary").Count
    requiredBusinessRoutes = $requiredBusinessRoutes
    missingBusinessRoutes = $missingRoutes
    failedCoverageCount = $failedCoverage.Count
    createdProbeUsers = @(
        [pscustomobject]@{ role = "FinanceManager"; username = $financeProbe.username },
        [pscustomobject]@{ role = "User"; username = $userProbe.username },
        [pscustomobject]@{ role = "Auditor"; username = $auditorProbe.username }
    )
    selectedIds = [pscustomobject]@{
        closePeriodId = [int]$closePeriod.periodId
        assetAccountId = [int]$assetAccount.accountId
        offsetAccountId = [int]$offsetAccount.accountId
        journalEntryId = $journalId
        reconciliationId = $reconciliationId
        importId = $validImportId
    }
    valid = ($missingRoutes.Count -eq 0 -and $failedCoverage.Count -eq 0)
    completedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$coverageSummary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $coverageSummaryPath -Encoding UTF8

if (-not $coverageSummary.valid) {
    throw "Endpoint coverage gate failed. Missing routes: $($missingRoutes -join ', '); failed probes: $($failedCoverage.Count)."
}

$zapExitCode = $null
$verifiedAlerts = @()
$htmlPath = Join-Path $outputDirFull "$OutputPrefix.html"
$jsonPath = Join-Path $outputDirFull "$OutputPrefix.json"
$markdownPath = Join-Path $outputDirFull "$OutputPrefix.md"

if (-not $SkipZapScan) {
    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("zap-v2-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force $workDir | Out-Null
    $rulesFileName = "zap-api-rules.tsv"
    Copy-Item -LiteralPath $rulesFileFull -Destination (Join-Path $workDir $rulesFileName) -Force

    $htmlName = "$OutputPrefix.html"
    $jsonName = "$OutputPrefix.json"
    $markdownName = "$OutputPrefix.md"
    $dockerOpenApiUrl = Convert-ToDockerReachableUrl -Url $normalizedOpenApiUrl
    $workMount = "$($workDir -replace '\\','/'):/zap/wrk"
    $tokenReplacement = "Bearer\ $adminToken"
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

    $dockerArgs = @(
        "run", "--rm",
        "-v", $workMount,
        $Image,
        "zap-api-scan.py",
        "-t", $dockerOpenApiUrl,
        "-f", "openapi",
        "-r", $htmlName,
        "-J", $jsonName,
        "-w", $markdownName,
        "-c", $rulesFileName,
        "-T", $Minutes.ToString(),
        "-z", $zapOptions
    )
    if ($SafeMode) {
        $dockerArgs += "-S"
    }
    if ($IgnoreWarnings) {
        $dockerArgs += "-I"
    }

    try {
        docker @dockerArgs
        $zapExitCode = $LASTEXITCODE

        foreach ($fileName in @($htmlName, $jsonName, $markdownName)) {
            $source = Join-Path $workDir $fileName
            if (Test-Path -LiteralPath $source) {
                Copy-Item -LiteralPath $source -Destination (Join-Path $outputDirFull $fileName) -Force
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($zapExitCode -notin @(0, 1, 2)) {
        throw "ZAP API scan failed with exit code $zapExitCode."
    }
    if ($zapExitCode -eq 2 -and -not $IgnoreWarnings) {
        throw "ZAP API scan completed with warnings and -IgnoreWarnings was not set."
    }

    $verifiedAlerts = Export-VerifiedZapAlerts -ZapJsonPath $jsonPath -OutputPath (Join-Path $outputDirFull "verified-alerts.json")
}
else {
    @() | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirFull "verified-alerts.json") -Encoding UTF8
}

$alertGroups = @($verifiedAlerts | Group-Object alertId | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject][ordered]@{
        alertId = $_.Name
        count = $_.Count
        name = [string]($_.Group | Select-Object -First 1).name
        risk = [string]($_.Group | Select-Object -First 1).risk
    }
})

$mediumOrHigher = @($verifiedAlerts | Where-Object { $_.risk -in @("Medium", "High") })
$runSummary = [pscustomobject][ordered]@{
    baseUrl = $normalizedBaseUrl
    openApiUrl = $normalizedOpenApiUrl
    dockerOpenApiUrl = if ($SkipZapScan) { "" } else { Convert-ToDockerReachableUrl -Url $normalizedOpenApiUrl }
    image = $Image
    outputPrefix = $OutputPrefix
    skipZapScan = [bool]$SkipZapScan
    safeMode = [bool]$SafeMode
    zapExitCode = $zapExitCode
    endpointCoveragePath = $coveragePath
    endpointCoverageSummaryPath = $coverageSummaryPath
    verifiedAlertsPath = Join-Path $outputDirFull "verified-alerts.json"
    htmlReportPath = if ($SkipZapScan) { "" } else { $htmlPath }
    jsonReportPath = if ($SkipZapScan) { "" } else { $jsonPath }
    markdownReportPath = if ($SkipZapScan) { "" } else { $markdownPath }
    verifiedBusinessAlertInstances = @($verifiedAlerts).Count
    distinctAlertIds = @($verifiedAlerts | Group-Object alertId).Count
    mediumOrHigherInstances = $mediumOrHigher.Count
    alertGroups = $alertGroups
    validityGate = [pscustomobject][ordered]@{
        endpointCoverage = [bool]$coverageSummary.valid
        atLeastEightBusinessAlertInstances = @($verifiedAlerts).Count -ge 8
        atLeastFourDistinctAlertIds = @($verifiedAlerts | Group-Object alertId).Count -ge 4
        atLeastTwoMediumOrHigherInstances = $mediumOrHigher.Count -ge 2
    }
    completedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$runSummary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputDirFull "zap-run-summary.json") -Encoding UTF8
Get-Content -LiteralPath (Join-Path $outputDirFull "zap-run-summary.json")
