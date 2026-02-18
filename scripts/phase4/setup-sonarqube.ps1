param(
    [string]$SonarUrl = "http://localhost:9000",
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "Admin@123456",
    [string]$AdminToken = "",
    [string]$NewAdminPassword = "",
    [string]$ProjectKey = "financial-accounting",
    [string]$ProjectName = "Financial Accounting",
    [string]$ProjectVisibility = "private",
    [string]$TokenName = "financial-accounting-token",
    [switch]$GenerateToken
)

$ErrorActionPreference = "Stop"

function New-BasicAuthHeader {
    param([string]$User, [string]$Password)
    $pair = "{0}:{1}" -f $User, $Password
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
    return @{ Authorization = "Basic $encoded" }
}

function Invoke-SonarApi {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Body,
        [hashtable]$Headers
    )

    $uri = "{0}{1}" -f $SonarUrl.TrimEnd('/'), $Path

    if ($null -ne $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers -Body $Body -ContentType "application/x-www-form-urlencoded"
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers
}

Write-Host "Checking SonarQube status at $SonarUrl"
$maxAttempts = 80
for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $status = (Invoke-RestMethod -Uri ("{0}/api/system/status" -f $SonarUrl.TrimEnd('/')) -TimeoutSec 5).status
        Write-Host "Status: $status"
        if ($status -eq "UP") {
            break
        }
    }
    catch {
        Write-Host "Waiting for SonarQube..."
    }

    Start-Sleep -Seconds 3
}

if ($status -ne "UP") {
    throw "SonarQube is not ready at $SonarUrl"
}

if (-not [string]::IsNullOrWhiteSpace($AdminToken)) {
    $authHeaders = @{ Authorization = "Bearer $AdminToken" }
    $authMode = "token"
}
else {
    $authHeaders = New-BasicAuthHeader -User $AdminUser -Password $AdminPassword
    $authMode = "basic"
}

if ($authMode -eq "basic" -and -not [string]::IsNullOrWhiteSpace($NewAdminPassword) -and $AdminPassword -ne $NewAdminPassword) {
    try {
        Invoke-SonarApi -Method "POST" -Path "/api/users/change_password" -Body @{
            login = $AdminUser
            previousPassword = $AdminPassword
            password = $NewAdminPassword
        } -Headers $authHeaders | Out-Null

        $AdminPassword = $NewAdminPassword
        $authHeaders = New-BasicAuthHeader -User $AdminUser -Password $AdminPassword
        Write-Host "Admin password updated."
    }
    catch {
        Write-Host "Password update skipped: $($_.Exception.Message)"
    }
}

try {
    $encodedKey = [Uri]::EscapeDataString($ProjectKey)
    $projectSearch = Invoke-SonarApi -Method "GET" -Path "/api/projects/search?projects=$encodedKey" -Body $null -Headers $authHeaders

    $projectExists = $false
    if ($projectSearch.components) {
        $projectExists = ($projectSearch.components | Where-Object { $_.key -eq $ProjectKey } | Measure-Object).Count -gt 0
    }

    if (-not $projectExists) {
        Invoke-SonarApi -Method "POST" -Path "/api/projects/create" -Body @{
            project = $ProjectKey
            name = $ProjectName
            visibility = $ProjectVisibility
        } -Headers $authHeaders | Out-Null

        Write-Host "Created SonarQube project: $ProjectKey"
    }
    else {
        Write-Host "Project already exists: $ProjectKey"
    }
}
catch {
    throw "SonarQube authentication failed. Provide valid -AdminPassword or -AdminToken. Details: $($_.Exception.Message)"
}

if ($GenerateToken) {
    try {
        $tokenResponse = Invoke-SonarApi -Method "POST" -Path "/api/user_tokens/generate" -Body @{ name = $TokenName } -Headers $authHeaders
        if ($tokenResponse.token) {
            Write-Host "Generated token (save this now, it is shown once):"
            Write-Host $tokenResponse.token
        }
    }
    catch {
        throw "Token generation failed. Use a valid admin credential/token. Details: $($_.Exception.Message)"
    }
}

Write-Host "SonarQube setup completed."
