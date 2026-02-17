param(
    [Parameter(Mandatory = $true)]
    [string]$SonarToken,

    [string]$SonarUrl = "http://localhost:9000",
    [string]$ProjectKey = "financial-accounting",
    [string]$ProjectName = "Financial Accounting",
    [string]$ProjectVersion = "1.0.$(Get-Date -Format yyyyMMddHHmmss)",
    [string]$SolutionPath = "API/API.csproj",
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

function Resolve-ScannerPath {
    $tool = Get-Command dotnet-sonarscanner -ErrorAction SilentlyContinue
    if ($tool) {
        return $tool.Source
    }

    Write-Host "Installing dotnet-sonarscanner global tool..."
    dotnet tool install --global dotnet-sonarscanner | Out-Null

    $defaultPath = Join-Path $env:USERPROFILE ".dotnet\\tools\\dotnet-sonarscanner.exe"
    if (Test-Path $defaultPath) {
        return $defaultPath
    }

    $tool = Get-Command dotnet-sonarscanner -ErrorAction SilentlyContinue
    if ($tool) {
        return $tool.Source
    }

    throw "dotnet-sonarscanner was not found after installation."
}

$scannerPath = Resolve-ScannerPath

$fullSolutionPath = [System.IO.Path]::GetFullPath($SolutionPath)
if (-not (Test-Path $fullSolutionPath)) {
    throw "Solution not found: $fullSolutionPath"
}

$beginArgs = @(
    "begin",
    "/k:$ProjectKey",
    "/n:$ProjectName",
    "/v:$ProjectVersion",
    "/d:sonar.host.url=$SonarUrl",
    "/d:sonar.token=$SonarToken"
)

Write-Host "Starting SonarScanner begin step..."
& $scannerPath @beginArgs

$buildSucceeded = $false
try {
    Write-Host "Building solution for analysis: $fullSolutionPath"
    dotnet build $fullSolutionPath -c $Configuration
    $buildSucceeded = $true
}
finally {
    Write-Host "Running SonarScanner end step..."
    & $scannerPath end "/d:sonar.token=$SonarToken"
}

if (-not $buildSucceeded) {
    throw "Build failed. Sonar upload may be incomplete."
}

Write-Host "SonarQube scan completed."
