param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$ExportRoot,

    [Parameter(Mandatory = $true)]
    [string]$BranchName,

    [string]$TargetRepository = "",
    [string]$CommitMessage = "test: create sanitized benchmark challenge source",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (Test-Path -LiteralPath $Source) {
        $parent = Split-Path -Parent $Destination
        if (-not [string]::IsNullOrWhiteSpace($parent)) {
            New-Item -ItemType Directory -Force $parent | Out-Null
        }
        Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    }
}

function Assert-SafeExportRoot {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = Resolve-FullPath -Path $Path
    if ($full.Length -lt 15) {
        throw "Refusing short export path: $full"
    }
    if ($full -match '^[A-Za-z]:\\$') {
        throw "Refusing drive root export path: $full"
    }
    if ($full -notmatch '\\\.worktrees\\|\\Temp\\') {
        throw "ExportRoot must be under a .worktrees or Temp directory: $full"
    }
}

if ($BranchName -notmatch '^codex/[A-Za-z0-9._-]+$') {
    throw "BranchName must use the codex/ prefix and safe branch characters."
}

$sourceRootFull = Resolve-FullPath -Path $SourceRoot
$exportRootFull = Resolve-FullPath -Path $ExportRoot
if ([string]::IsNullOrWhiteSpace($TargetRepository)) {
    $TargetRepository = $sourceRootFull
}
$targetRepoFull = Resolve-FullPath -Path $TargetRepository

if (-not (Test-Path -LiteralPath $sourceRootFull)) {
    throw "SourceRoot does not exist: $sourceRootFull"
}
if (-not (Test-Path -LiteralPath (Join-Path $targetRepoFull ".git"))) {
    $gitDir = & git -C $targetRepoFull rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitDir)) {
        throw "TargetRepository is not a git checkout: $targetRepoFull"
    }
}

Assert-SafeExportRoot -Path $exportRootFull
if (Test-Path -LiteralPath $exportRootFull) {
    if (-not $Force) {
        throw "ExportRoot already exists. Re-run with -Force after checking the target: $exportRootFull"
    }

    Remove-Item -LiteralPath $exportRootFull -Recurse -Force
}
New-Item -ItemType Directory -Force $exportRootFull | Out-Null

foreach ($directory in @("API", "BAL", "MODEL", "tests")) {
    Copy-IfExists -Source (Join-Path $sourceRootFull $directory) -Destination (Join-Path $exportRootFull $directory)
}

foreach ($file in @(
    ".gitignore",
    "Directory.Build.props",
    "Directory.Build.targets",
    "global.json",
    "README.md",
    "FINANCIAL_API_DB_TABLES_AND_ENDPOINTS.md"
)) {
    Copy-IfExists -Source (Join-Path $sourceRootFull $file) -Destination (Join-Path $exportRootFull $file)
}

Copy-IfExists -Source (Join-Path $sourceRootFull "Document\sql") -Destination (Join-Path $exportRootFull "Document\sql")
Copy-IfExists -Source (Join-Path $sourceRootFull "Document\performance\jmeter") -Destination (Join-Path $exportRootFull "Document\performance\jmeter")

New-Item -ItemType Directory -Force (Join-Path $exportRootFull "scripts") | Out-Null
if (Test-Path -LiteralPath (Join-Path $sourceRootFull "scripts\phase4")) {
    Copy-IfExists -Source (Join-Path $sourceRootFull "scripts\phase4") -Destination (Join-Path $exportRootFull "scripts\phase4")
}
if (Test-Path -LiteralPath (Join-Path $sourceRootFull "scripts\benchmark-v2")) {
    $benchmarkScriptsDestination = Join-Path $exportRootFull "scripts\benchmark-v2"
    New-Item -ItemType Directory -Force $benchmarkScriptsDestination | Out-Null
    foreach ($benchmarkScript in @("restore-benchmark-database.ps1", "run-jmeter-workflows.ps1")) {
        Copy-IfExists `
            -Source (Join-Path $sourceRootFull "scripts\benchmark-v2\$benchmarkScript") `
            -Destination (Join-Path $benchmarkScriptsDestination $benchmarkScript)
    }
}

$blockedPattern = "sonar-mutations|hidden-tests|gpt-5\.4-vs-gpt-5\.5|baseline-sonarqube-v1|baseline-zap-v1|baseline-jmeter-v1|benchmark-v2-reference-code|Document\\outputs"
$leaks = @(& rg -n -uu $blockedPattern $exportRootFull 2>$null)
if ($leaks.Count -gt 0) {
    $preview = ($leaks | Select-Object -First 20) -join "`n"
    throw "Sanitized export contains blocked benchmark/controller references:`n$preview"
}

$blockedPathPattern = '\\controller\\|\\hidden-tests\\|\\gpt-5\.4-vs-gpt-5\.5'
$pathLeaks = @(
    Get-ChildItem -LiteralPath $exportRootFull -Recurse -Force |
        Where-Object { $_.FullName.Substring($exportRootFull.Length) -match $blockedPathPattern } |
        Select-Object -ExpandProperty FullName
)
if ($pathLeaks.Count -gt 0) {
    $preview = ($pathLeaks | Select-Object -First 20) -join "`n"
    throw "Sanitized export contains blocked benchmark/controller paths:`n$preview"
}

& git -C $exportRootFull init | Out-Null
& git -C $exportRootFull add -A
if ($LASTEXITCODE -ne 0) {
    throw "git add failed in sanitized export."
}
& git -C $exportRootFull commit -m $CommitMessage | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "git commit failed in sanitized export."
}

$rootCount = (& git -C $exportRootFull rev-list --count HEAD).Trim()
if ($rootCount -ne "1") {
    throw "Sanitized export must contain exactly one commit; found $rootCount."
}

$exportCommit = (& git -C $exportRootFull rev-parse HEAD).Trim()

$null = & git -C $targetRepoFull show-ref --verify --quiet "refs/heads/$BranchName"
$branchExists = $LASTEXITCODE -eq 0
if ($branchExists) {
    if (-not $Force) {
        throw "Target branch already exists: $BranchName"
    }
    & git -C $targetRepoFull update-ref -d "refs/heads/$BranchName"
}

& git -C $targetRepoFull fetch $exportRootFull "HEAD:refs/heads/$BranchName" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to import sanitized root commit into target repository branch $BranchName."
}

[ordered]@{
    branchName = $BranchName
    exportRoot = $exportRootFull
    exportCommit = $exportCommit
    rootCommitCount = [int]$rootCount
    importedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 4
