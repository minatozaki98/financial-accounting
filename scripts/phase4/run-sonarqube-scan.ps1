param(
    [Parameter(Mandatory = $true)]
    [string]$SonarToken,

    [string]$SonarUrl = "http://localhost:9000",
    [string]$ProjectKey = "financial-accounting",
    [string]$ProjectName = "Financial Accounting",
    [string]$ProjectVersion = "1.0.$(Get-Date -Format yyyyMMddHHmmss)",
    [string]$SolutionPath = "API/API.sln",
    [string]$Configuration = "Debug",
    [string]$UnitTestProjectPath = "tests/FinancialAccounting.UnitTests/FinancialAccounting.UnitTests.csproj",
    [string]$IntegrationTestProjectPath = "tests/FinancialAccounting.IntegrationTests/FinancialAccounting.IntegrationTests.csproj",
    [string]$ArtifactsDirectory = ".tmp/sonar"
)

$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter(Mandatory = $true)]
        [string]$InstallCommand,

        [string]$DefaultPath
    )

    $tool = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($tool) {
        return $tool.Source
    }

    Write-Host "Installing $CommandName global tool..."
    Invoke-Expression $InstallCommand | Out-Null

    if ($DefaultPath -and (Test-Path $DefaultPath)) {
        return $DefaultPath
    }

    $tool = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($tool) {
        return $tool.Source
    }

    throw "$CommandName was not found after installation."
}

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Invoke-TrackedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    & $ScriptBlock
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

$scannerPath = Resolve-ToolPath `
    -CommandName "dotnet-sonarscanner" `
    -InstallCommand "dotnet tool install --global dotnet-sonarscanner" `
    -DefaultPath (Join-Path $env:USERPROFILE ".dotnet\\tools\\dotnet-sonarscanner.exe")

$coverageToolPath = Resolve-ToolPath `
    -CommandName "dotnet-coverage" `
    -InstallCommand "dotnet tool install --global dotnet-coverage" `
    -DefaultPath (Join-Path $env:USERPROFILE ".dotnet\\tools\\dotnet-coverage.exe")

$fullSolutionPath = Resolve-FullPath -Path $SolutionPath
$fullUnitTestProjectPath = Resolve-FullPath -Path $UnitTestProjectPath
$fullIntegrationTestProjectPath = Resolve-FullPath -Path $IntegrationTestProjectPath
$fullArtifactsDirectory = Resolve-FullPath -Path $ArtifactsDirectory

foreach ($pathCheck in @(
    @{ Label = "Solution"; Path = $fullSolutionPath },
    @{ Label = "Unit test project"; Path = $fullUnitTestProjectPath },
    @{ Label = "Integration test project"; Path = $fullIntegrationTestProjectPath }
)) {
    if (-not (Test-Path $pathCheck.Path)) {
        throw "$($pathCheck.Label) not found: $($pathCheck.Path)"
    }
}

$coverageDirectory = Join-Path $fullArtifactsDirectory "coverage"
$testResultsDirectory = Join-Path $fullArtifactsDirectory "test-results"
$null = New-Item -ItemType Directory -Path $coverageDirectory -Force
$null = New-Item -ItemType Directory -Path $testResultsDirectory -Force

$unitCoveragePath = Join-Path $coverageDirectory "unit-coverage.xml"
$integrationCoveragePath = Join-Path $coverageDirectory "integration-coverage.xml"
$coverageReportPaths = "$unitCoveragePath,$integrationCoveragePath"

$beginArgs = @(
    "begin",
    "/k:$ProjectKey",
    "/n:$ProjectName",
    "/v:$ProjectVersion",
    "/d:sonar.host.url=$SonarUrl",
    "/d:sonar.token=$SonarToken",
    "/d:sonar.scanner.scanAll=false",
    "/d:sonar.cs.vscoveragexml.reportsPaths=$coverageReportPaths"
)

Write-Host "Starting SonarScanner begin step..."
Invoke-TrackedCommand -ScriptBlock { & $scannerPath @beginArgs } -FailureMessage "SonarScanner begin step failed."

$buildSucceeded = $false
try {
    Write-Host "Building solution for analysis: $fullSolutionPath"
    Invoke-TrackedCommand `
        -ScriptBlock { dotnet build $fullSolutionPath -c $Configuration } `
        -FailureMessage "dotnet build failed."

    $coverageRuns = @(
        @{
            Name = "unit"
            ProjectPath = $fullUnitTestProjectPath
            CoveragePath = $unitCoveragePath
            ResultsPath = Join-Path $testResultsDirectory "unit"
            LogFileName = "unit.trx"
        },
        @{
            Name = "integration"
            ProjectPath = $fullIntegrationTestProjectPath
            CoveragePath = $integrationCoveragePath
            ResultsPath = Join-Path $testResultsDirectory "integration"
            LogFileName = "integration.trx"
        }
    )

    foreach ($coverageRun in $coverageRuns) {
        $null = New-Item -ItemType Directory -Path $coverageRun.ResultsPath -Force
        Write-Host "Collecting $($coverageRun.Name) coverage for Sonar: $($coverageRun.ProjectPath)"

        $coverageCommand = "dotnet test `"$($coverageRun.ProjectPath)`" -c $Configuration --no-build --logger `"trx;LogFileName=$($coverageRun.LogFileName)`" --results-directory `"$($coverageRun.ResultsPath)`""

        Invoke-TrackedCommand `
            -ScriptBlock {
                & $coverageToolPath collect $coverageCommand -f xml -o $coverageRun.CoveragePath
            } `
            -FailureMessage "dotnet-coverage collection failed for $($coverageRun.Name) tests."
    }

    $buildSucceeded = $true
}
finally {
    Write-Host "Running SonarScanner end step..."
    Invoke-TrackedCommand -ScriptBlock { & $scannerPath end "/d:sonar.token=$SonarToken" } -FailureMessage "SonarScanner end step failed."
}

if (-not $buildSucceeded) {
    throw "Build failed. Sonar upload may be incomplete."
}

Write-Host "SonarQube scan completed."
