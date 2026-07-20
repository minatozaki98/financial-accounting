param(
    [Parameter(Mandatory = $true)]
    [string]$SonarToken,

    [string]$SonarUrl = "http://localhost:9000",
    [string]$ProjectKey = "financial-accounting-sonar-v2",
    [string]$ProjectName = "Financial Accounting Sonar v2",
    [string]$ProjectVersion = "1.0",
    [string]$SolutionPath = "API/API.sln",
    [string]$Configuration = "Debug",
    [string]$OutputDir = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/baseline/sonar"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function New-SonarTokenHeader {
    param([Parameter(Mandatory = $true)][string]$Token)

    $raw = "{0}:" -f $Token
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($raw))
    return @{ Authorization = "Basic $encoded" }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    & $FilePath @Arguments *> $LogPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}. See log: $LogPath"
    }
}

function Resolve-ToolPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Required tool was not found on PATH: $Name"
}

function Wait-SonarComputeTask {
    param(
        [Parameter(Mandatory = $true)][string]$TaskId,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    $deadline = (Get-Date).AddMinutes(5)
    do {
        $encodedTask = [Uri]::EscapeDataString($TaskId)
        $task = Invoke-RestMethod -Method GET -Uri "$($BaseUrl.TrimEnd('/'))/api/ce/task?id=$encodedTask" -Headers $Headers
        $status = [string]$task.task.status
        if ($status -eq "SUCCESS") {
            return $task
        }
        if ($status -in @("FAILED", "CANCELED")) {
            throw "SonarQube compute task $TaskId ended with status $status."
        }

        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for SonarQube compute task $TaskId."
}

$solutionFullPath = Resolve-FullPath -Path $SolutionPath
$outputDirFull = Resolve-FullPath -Path $OutputDir
$coveragePath = Join-Path $outputDirFull "coverage.xml"
$scannerBeginLog = Join-Path $outputDirFull "scanner-begin.log"
$buildLog = Join-Path $outputDirFull "build.log"
$testLog = Join-Path $outputDirFull "test-coverage.log"
$scannerEndLog = Join-Path $outputDirFull "scanner-end.log"

if (-not (Test-Path -LiteralPath $solutionFullPath)) {
    throw "Solution not found: $solutionFullPath"
}

New-Item -ItemType Directory -Force $outputDirFull | Out-Null

$headers = New-SonarTokenHeader -Token $SonarToken
try {
    Invoke-RestMethod -Method POST -Uri "$($SonarUrl.TrimEnd('/'))/api/projects/create" -Headers $headers -Body @{
        project = $ProjectKey
        name = $ProjectName
        visibility = "private"
    } -ContentType "application/x-www-form-urlencoded" | Out-Null
}
catch {
    if ($_.Exception.Message -notmatch "400|already|exists") {
        throw
    }
}

$scannerPath = Resolve-ToolPath -Name "dotnet-sonarscanner"
$coveragePathTool = Resolve-ToolPath -Name "dotnet-coverage"

$beginArgs = @(
    "begin",
    "/k:$ProjectKey",
    "/n:$ProjectName",
    "/v:$ProjectVersion",
    "/d:sonar.host.url=$SonarUrl",
    "/d:sonar.token=$SonarToken",
    "/d:sonar.cs.vscoveragexml.reportsPaths=$coveragePath"
)

Invoke-External -FilePath $scannerPath -Arguments $beginArgs -LogPath $scannerBeginLog

try {
    Invoke-External -FilePath "dotnet" -Arguments @("build", $solutionFullPath, "-c", $Configuration, "--nologo") -LogPath $buildLog

    $testCommand = "dotnet test `"$solutionFullPath`" -c $Configuration --no-build --nologo"
    Invoke-External -FilePath $coveragePathTool -Arguments @(
        "collect",
        $testCommand,
        "-f",
        "xml",
        "-o",
        $coveragePath,
        "--nologo"
    ) -LogPath $testLog
}
finally {
    Invoke-External -FilePath $scannerPath -Arguments @("end", "/d:sonar.token=$SonarToken") -LogPath $scannerEndLog
}

$reportTaskPath = Join-Path (Get-Location) ".sonarqube\out\.sonar\report-task.txt"
if (-not (Test-Path -LiteralPath $reportTaskPath)) {
    throw "Sonar report-task.txt was not found: $reportTaskPath"
}

$reportTask = @{}
foreach ($line in Get-Content -LiteralPath $reportTaskPath) {
    $parts = $line -split "=", 2
    if ($parts.Count -eq 2) {
        $reportTask[$parts[0]] = $parts[1]
    }
}

if ([string]::IsNullOrWhiteSpace($reportTask["ceTaskId"])) {
    throw "Sonar report-task.txt did not include ceTaskId."
}

$task = Wait-SonarComputeTask -TaskId $reportTask["ceTaskId"] -BaseUrl $SonarUrl -Headers $headers

[ordered]@{
    projectKey = $ProjectKey
    projectName = $ProjectName
    projectVersion = $ProjectVersion
    solutionPath = $solutionFullPath
    outputDir = $outputDirFull
    coveragePath = $coveragePath
    ceTaskId = $reportTask["ceTaskId"]
    ceTaskStatus = $task.task.status
    analysisId = $task.task.analysisId
    completedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $outputDirFull "scan-summary.json") -Encoding UTF8

Get-Content -LiteralPath (Join-Path $outputDirFull "scan-summary.json")
