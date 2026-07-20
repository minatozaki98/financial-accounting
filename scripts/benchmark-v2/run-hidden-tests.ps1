param(
    [Parameter(Mandatory = $true)]
    [string]$CandidateRoot,

    [string]$RunTag = "candidate",
    [string]$ResultsDir = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2/results/hidden-tests"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

$candidateRootFull = Resolve-FullPath -Path $CandidateRoot
$resultsDirFull = Resolve-FullPath -Path $ResultsDir
$hiddenProject = Join-Path $PSScriptRoot "..\..\Document\experiments\gpt-5.4-vs-gpt-5.5-v2\controller\hidden-tests\FinancialAccounting.BenchmarkHiddenTests.csproj"
$hiddenProjectFull = [System.IO.Path]::GetFullPath($hiddenProject)

if (-not (Test-Path -LiteralPath $candidateRootFull)) {
    throw "CandidateRoot does not exist: $candidateRootFull"
}

foreach ($requiredPath in @("API\API.csproj", "BAL\BAL.csproj", "MODEL\MODEL.csproj", "tests\FinancialAccounting.IntegrationTests\FinancialAccounting.IntegrationTests.csproj")) {
    $fullPath = Join-Path $candidateRootFull $requiredPath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "CandidateRoot is missing required project path: $fullPath"
    }
}

if (Test-Path -LiteralPath (Join-Path $candidateRootFull ".git")) {
    $status = & git -C $candidateRootFull status --short
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect candidate git status."
    }
    if (($status | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw "CandidateRoot must be clean before hidden verification: $candidateRootFull"
    }
}

if (-not (Test-Path -LiteralPath $hiddenProjectFull)) {
    throw "Hidden test project was not found: $hiddenProjectFull"
}

New-Item -ItemType Directory -Force $resultsDirFull | Out-Null

& dotnet test $hiddenProjectFull `
    "-p:CandidateRoot=$candidateRootFull" `
    --logger "trx;LogFileName=hidden-$RunTag.trx" `
    --results-directory $resultsDirFull `
    --nologo
$exitCode = $LASTEXITCODE

$trxPath = Join-Path $resultsDirFull "hidden-$RunTag.trx"
if (Test-Path -LiteralPath $trxPath) {
    [xml]$trx = Get-Content -LiteralPath $trxPath -Raw
    $counters = $trx.TestRun.ResultSummary.Counters
    $summary = [ordered]@{
        runTag = $RunTag
        candidateRoot = $candidateRootFull
        outcome = [string]$trx.TestRun.ResultSummary.outcome
        total = [int]$counters.total
        executed = [int]$counters.executed
        passed = [int]$counters.passed
        failed = [int]$counters.failed
        skipped = [int]$counters.notExecuted
        trxPath = $trxPath
        completedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    }

    $summary | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $resultsDirFull "hidden-$RunTag-summary.json") -Encoding UTF8
}

if ($exitCode -ne 0) {
    throw "Hidden tests failed with exit code $exitCode."
}
