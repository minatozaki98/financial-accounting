param(
    [string]$SqlServer = "localhost",
    [string]$TargetDatabase = "FinancialBenchmarkV2",
    [string]$BackupPath = "",
    [string]$ExpectedSha256 = "",
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

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

if ($TargetDatabase -notmatch '^[A-Za-z0-9_]+$') {
    throw "TargetDatabase must contain only letters, digits, and underscore."
}

if (@("master", "model", "msdb", "tempdb") -contains $TargetDatabase) {
    throw "Refusing to restore over protected system database '$TargetDatabase'."
}

if ($TargetDatabase -eq "Financial") {
    throw "Refusing to restore over app default database 'Financial'. Use the isolated FinancialBenchmarkV2 database for benchmark runs."
}

if (-not $Force) {
    throw "Restore replaces database '$TargetDatabase'. Re-run with -Force after verifying the target name."
}

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $BackupPath = Join-Path ([System.IO.Path]::GetTempPath()) "financial-accounting-benchmark-v2\financial-benchmark-v2-clean.bak"
}

$backupPathFull = Resolve-FullPath -Path $BackupPath
if (-not (Test-Path -LiteralPath $backupPathFull)) {
    throw "Benchmark backup was not found: $backupPathFull"
}

if ([string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $hashFile = "$backupPathFull.sha256"
    if (-not (Test-Path -LiteralPath $hashFile)) {
        throw "ExpectedSha256 was not provided and hash file is missing: $hashFile"
    }
    $ExpectedSha256 = (Get-Content -LiteralPath $hashFile -Raw).Trim()
}

$actualHash = (Get-FileHash -LiteralPath $backupPathFull -Algorithm SHA256).Hash
if (-not [string]::Equals($actualHash, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Benchmark backup hash mismatch. Expected $ExpectedSha256 but found $actualHash."
}

$restoreSql = @"
IF DB_ID(N'$($TargetDatabase.Replace("'", "''"))') IS NOT NULL
BEGIN
    ALTER DATABASE [$TargetDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END;

RESTORE DATABASE [$TargetDatabase]
FROM DISK = N'$($backupPathFull.Replace("'", "''"))'
WITH REPLACE, CHECKSUM, RECOVERY, STATS = 10;

ALTER DATABASE [$TargetDatabase] SET MULTI_USER;
"@

Invoke-Checked -FilePath "sqlcmd" -Arguments @("-S", $SqlServer, "-E", "-b", "-Q", $restoreSql)

[ordered]@{
    sqlServer = $SqlServer
    targetDatabase = $TargetDatabase
    backupPath = $backupPathFull
    backupSha256 = $actualHash
    restoredAtUtc = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 4
