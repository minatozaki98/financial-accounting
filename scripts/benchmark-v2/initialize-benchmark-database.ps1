param(
    [string]$SqlServer = "localhost",
    [string]$DatabaseName = "FinancialBenchmarkV2",
    [string]$ExperimentRoot = "Document/experiments/gpt-5.4-vs-gpt-5.5-v2",
    [string]$BackupPath = "",
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

function Invoke-SqlText {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [string]$Database = "master"
    )

    $output = & sqlcmd -S $SqlServer -E -d $Database -b -h -1 -W -Q "SET NOCOUNT ON; $Query"
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd query failed: $Query"
    }

    return (($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n").Trim()
}

function Test-DatabaseExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    $result = Invoke-SqlText -Query "SELECT CASE WHEN DB_ID(N'$($Name.Replace("'", "''"))') IS NULL THEN 0 ELSE 1 END;"
    return $result -eq "1"
}

function Assert-SafeDatabaseName {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($Name -notmatch '^[A-Za-z0-9_]+$') {
        throw "DatabaseName must contain only letters, digits, and underscore."
    }

    if (@("master", "model", "msdb", "tempdb", "Financial") -contains $Name) {
        throw "Refusing to initialize protected or non-benchmark database '$Name'. Use FinancialBenchmarkV2."
    }
}

function Write-JournalImportFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$Rows,
        [Parameter(Mandatory = $true)][string]$DebitAccountCode,
        [Parameter(Mandatory = $true)][string]$CreditAccountCode
    )

    $writer = [System.IO.StreamWriter]::new($Path, $false, [System.Text.UTF8Encoding]::new($false))
    try {
        $writer.WriteLine("EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit")
        for ($i = 1; $i -le $Rows; $i++) {
            $pairNumber = [int][Math]::Ceiling($i / 2)
            $reference = "V2-FIX-{0:D5}" -f $pairNumber
            $amount = "{0:0.00}" -f (10 + ($pairNumber % 9000))
            if ($i % 2 -eq 1) {
                $writer.WriteLine("2026-04-01,$reference,Fixture debit $pairNumber,$DebitAccountCode,$amount,0")
            }
            else {
                $writer.WriteLine("2026-04-01,$reference,Fixture credit $pairNumber,$CreditAccountCode,0,$amount")
            }
        }
    }
    finally {
        $writer.Dispose()
    }
}

Assert-SafeDatabaseName -Name $DatabaseName

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$schemaPath = Join-Path $repoRoot "Document\sql\financial_accounting_schema.sql"
$seedScriptPath = Join-Path $repoRoot "scripts\phase4\seed-test-data.ps1"
$experimentRootFull = Resolve-FullPath -Path $ExperimentRoot
$databaseDir = Join-Path $experimentRootFull "database"
$fixtureDir = Join-Path $experimentRootFull "fixtures\journal-import"

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $BackupPath = Join-Path ([System.IO.Path]::GetTempPath()) "financial-accounting-benchmark-v2\financial-benchmark-v2-clean.bak"
}

$backupPathFull = Resolve-FullPath -Path $BackupPath
New-Item -ItemType Directory -Force $databaseDir, $fixtureDir, (Split-Path -Parent $backupPathFull) | Out-Null

if (-not (Test-Path -LiteralPath $schemaPath)) {
    throw "Schema file was not found: $schemaPath"
}

if (-not (Test-Path -LiteralPath $seedScriptPath)) {
    throw "Seed script was not found: $seedScriptPath"
}

if ((Test-DatabaseExists -Name $DatabaseName) -and -not $Force) {
    throw "Database '$DatabaseName' already exists. Re-run with -Force to replace the benchmark database."
}

if (Test-DatabaseExists -Name $DatabaseName) {
    $dropSql = @"
ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE [$DatabaseName];
"@
    Invoke-Checked -FilePath "sqlcmd" -Arguments @("-S", $SqlServer, "-E", "-b", "-Q", $dropSql)
}

$schemaTemp = Join-Path $env:TEMP ("financial-accounting-schema-{0}.sql" -f ([Guid]::NewGuid().ToString("N")))
$extraSeedTemp = Join-Path $env:TEMP ("financial-accounting-v2-seed-{0}.sql" -f ([Guid]::NewGuid().ToString("N")))

try {
    $schemaSql = Get-Content -LiteralPath $schemaPath -Raw
    $schemaSql = $schemaSql.Replace("IF DB_ID(N'Financial') IS NULL", "IF DB_ID(N'$DatabaseName') IS NULL")
    $schemaSql = $schemaSql.Replace("CREATE DATABASE [Financial];", "CREATE DATABASE [$DatabaseName];")
    $schemaSql = $schemaSql.Replace("USE [Financial];", "USE [$DatabaseName];")
    $schemaSql = "SET ANSI_NULLS ON;`r`nSET QUOTED_IDENTIFIER ON;`r`nGO`r`n$schemaSql"
    Set-Content -LiteralPath $schemaTemp -Value $schemaSql -Encoding UTF8

    Invoke-Checked -FilePath "sqlcmd" -Arguments @("-S", $SqlServer, "-E", "-b", "-i", $schemaTemp)

    $connectionString = "Server=$SqlServer;Database=$DatabaseName;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=false;"
    & $seedScriptPath `
        -ConnectionString $connectionString `
        -PeriodId 202601 `
        -PeriodStart "2026-01-01" `
        -PeriodEnd "2026-12-31" `
        -AccountCount 200 `
        -JournalEntryCount 50000 `
        -MinimumPostedEntries 50000 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Phase-4 seed script failed."
    }

    $extraSeedSql = @"
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

USE [$DatabaseName];

DECLARE @AdminUserId uniqueidentifier = (
    SELECT TOP (1) UserId FROM dbo.Users WHERE Username = N'admin' ORDER BY CreatedAt
);
IF @AdminUserId IS NULL
    THROW 51000, 'Admin user was not seeded.', 1;

;WITH M AS
(
    SELECT TOP (24) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
),
Periods AS
(
    SELECT
        (2027 + ((n - 1) / 12)) * 100 + (((n - 1) % 12) + 1) AS PeriodId,
        DATEFROMPARTS(2027 + ((n - 1) / 12), ((n - 1) % 12) + 1, 1) AS StartDate,
        EOMONTH(DATEFROMPARTS(2027 + ((n - 1) / 12), ((n - 1) % 12) + 1, 1)) AS EndDate
    FROM M
)
MERGE dbo.AccountingPeriods AS target
USING Periods AS source
ON target.PeriodId = source.PeriodId
WHEN MATCHED THEN
    UPDATE SET
        StartDate = source.StartDate,
        EndDate = source.EndDate,
        IsClosed = 0,
        ClosedAt = NULL,
        ClosedByUserId = NULL,
        CloseRequestId = NULL,
        Version = 1
WHEN NOT MATCHED THEN
    INSERT (PeriodId, StartDate, EndDate, IsClosed, ClosedAt, ClosedByUserId, CloseRequestId, Version)
    VALUES (source.PeriodId, source.StartDate, source.EndDate, 0, NULL, NULL, NULL, 1);

DECLARE @ReconciliationId uniqueidentifier = CONVERT(uniqueidentifier, '11111111-2222-3333-4444-555555555555');
DECLARE @BankAccountId int = (
    SELECT TOP (1) AccountId
    FROM dbo.ChartOfAccounts
    WHERE AccountType = N'Asset' AND IsActive = 1
    ORDER BY AccountId
);
IF @BankAccountId IS NULL
    THROW 51001, 'Bank account was not seeded.', 1;

DELETE c
FROM dbo.BankReconciliationCandidates c
INNER JOIN dbo.BankTransactions bt ON bt.BankTransactionId = c.BankTransactionId
WHERE bt.ReconciliationId = @ReconciliationId;

DELETE FROM dbo.BankTransactions WHERE ReconciliationId = @ReconciliationId;
DELETE FROM dbo.BankReconciliations WHERE ReconciliationId = @ReconciliationId;

INSERT INTO dbo.BankReconciliations
(
    ReconciliationId, PeriodId, BankAccountId, DateFrom, DateTo, Status,
    CreatedByUserId, CreatedAt, FinalizedAt, FinalizeRequestId, Version
)
VALUES
(
    @ReconciliationId, 202601, @BankAccountId, '2026-01-01', '2026-12-31',
    N'Draft', @AdminUserId, SYSUTCDATETIME(), NULL, NULL, 1
);

SELECT TOP (5000)
    ROW_NUMBER() OVER (ORDER BY je.JournalEntryId) AS rn,
    je.JournalEntryId,
    je.ReferenceNo,
    CAST(SUM(jel.Debit) AS decimal(18,2)) AS Amount
INTO #PostedEntries
FROM dbo.JournalEntries je
INNER JOIN dbo.JournalEntryLines jel ON jel.JournalEntryId = je.JournalEntryId
WHERE je.Status = N'Posted'
GROUP BY je.JournalEntryId, je.ReferenceNo
ORDER BY je.JournalEntryId;

IF (SELECT COUNT(*) FROM #PostedEntries) < 5000
    THROW 51002, 'At least 5,000 posted entries are required for reconciliation fixtures.', 1;

;WITH N AS
(
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.BankTransactions
(
    ReconciliationId, TransactionDate, Amount, ReferenceNo, Description,
    MatchStatus, MatchedJournalEntryId
)
SELECT
    @ReconciliationId,
    DATEADD(DAY, (n - 1) % 365, CONVERT(date, '2026-01-01')),
    CASE WHEN n <= 3750 THEN pe.Amount ELSE CAST(900000 + n AS decimal(18,2)) END,
    CASE WHEN n <= 3750 THEN pe.ReferenceNo ELSE CONCAT(N'UNMATCHED-', RIGHT(N'00000' + CONVERT(nvarchar(5), n), 5)) END,
    CASE
        WHEN n <= 2500 THEN N'Exact reconciliation fixture'
        WHEN n <= 3750 THEN N'Ambiguous reconciliation fixture'
        ELSE N'Unmatched reconciliation fixture'
    END,
    N'Unmatched',
    NULL
FROM N
LEFT JOIN #PostedEntries pe ON pe.rn = n;

SELECT
    ROW_NUMBER() OVER (ORDER BY BankTransactionId) AS rn,
    BankTransactionId
INTO #BankTransactions
FROM dbo.BankTransactions
WHERE ReconciliationId = @ReconciliationId;

INSERT INTO dbo.BankReconciliationCandidates (BankTransactionId, JournalEntryId, Score, IsSelected)
SELECT bt.BankTransactionId, pe.JournalEntryId, 100, 0
FROM #BankTransactions bt
INNER JOIN #PostedEntries pe ON pe.rn = bt.rn
WHERE bt.rn <= 2500;

INSERT INTO dbo.BankReconciliationCandidates (BankTransactionId, JournalEntryId, Score, IsSelected)
SELECT bt.BankTransactionId, pe.JournalEntryId, 95, 0
FROM #BankTransactions bt
INNER JOIN #PostedEntries pe ON pe.rn = bt.rn
WHERE bt.rn > 2500 AND bt.rn <= 3750;

INSERT INTO dbo.BankReconciliationCandidates (BankTransactionId, JournalEntryId, Score, IsSelected)
SELECT bt.BankTransactionId, pe.JournalEntryId, 95, 0
FROM #BankTransactions bt
INNER JOIN #PostedEntries pe ON pe.rn = bt.rn + 1250
WHERE bt.rn > 2500 AND bt.rn <= 3750;

IF (SELECT COUNT(*) FROM dbo.AccountingPeriods) < 24
    THROW 51003, 'Benchmark database must contain at least 24 accounting periods.', 1;
IF (SELECT COUNT(*) FROM dbo.ChartOfAccounts WHERE IsActive = 1) < 200
    THROW 51004, 'Benchmark database must contain at least 200 active accounts.', 1;
IF (SELECT COUNT(*) FROM dbo.JournalEntries WHERE Status = N'Posted') < 50000
    THROW 51005, 'Benchmark database must contain at least 50,000 posted journal entries.', 1;
IF (SELECT COUNT(*) FROM dbo.BankReconciliationCandidates) < 5000
    THROW 51006, 'Benchmark database must contain at least 5,000 reconciliation candidates.', 1;
"@
    Set-Content -LiteralPath $extraSeedTemp -Value $extraSeedSql -Encoding UTF8
    Invoke-Checked -FilePath "sqlcmd" -Arguments @("-S", $SqlServer, "-E", "-b", "-d", $DatabaseName, "-i", $extraSeedTemp)

    $assetCode = Invoke-SqlText -Database $DatabaseName -Query "SELECT TOP (1) AccountCode FROM dbo.ChartOfAccounts WHERE AccountType = N'Asset' AND IsActive = 1 ORDER BY AccountId;"
    $liabilityCode = Invoke-SqlText -Database $DatabaseName -Query "SELECT TOP (1) AccountCode FROM dbo.ChartOfAccounts WHERE AccountType = N'Liability' AND IsActive = 1 ORDER BY AccountId;"
    if ([string]::IsNullOrWhiteSpace($assetCode) -or [string]::IsNullOrWhiteSpace($liabilityCode)) {
        throw "Could not resolve fixture account codes."
    }

    foreach ($rowCount in @(10, 100, 1000, 10000)) {
        $fixturePath = Join-Path $fixtureDir ("journal-import-valid-{0}.csv" -f $rowCount)
        Write-JournalImportFixture -Path $fixturePath -Rows $rowCount -DebitAccountCode $assetCode -CreditAccountCode $liabilityCode
    }

    $backupSql = @"
BACKUP DATABASE [$DatabaseName]
TO DISK = N'$($backupPathFull.Replace("'", "''"))'
WITH INIT, COPY_ONLY, CHECKSUM, COMPRESSION, STATS = 10;
RESTORE VERIFYONLY
FROM DISK = N'$($backupPathFull.Replace("'", "''"))'
WITH CHECKSUM;
"@
    Invoke-Checked -FilePath "sqlcmd" -Arguments @("-S", $SqlServer, "-E", "-b", "-Q", $backupSql)

    $hash = (Get-FileHash -LiteralPath $backupPathFull -Algorithm SHA256).Hash
    Set-Content -LiteralPath "$backupPathFull.sha256" -Value $hash -Encoding ASCII

    $summary = [ordered]@{
        databaseName = $DatabaseName
        sqlServer = $SqlServer
        backupPath = $backupPathFull
        backupSha256 = $hash
        accountingPeriods = [int](Invoke-SqlText -Database $DatabaseName -Query "SELECT COUNT(*) FROM dbo.AccountingPeriods;")
        activeAccounts = [int](Invoke-SqlText -Database $DatabaseName -Query "SELECT COUNT(*) FROM dbo.ChartOfAccounts WHERE IsActive = 1;")
        postedJournalEntries = [int](Invoke-SqlText -Database $DatabaseName -Query "SELECT COUNT(*) FROM dbo.JournalEntries WHERE Status = N'Posted';")
        reconciliationTransactions = [int](Invoke-SqlText -Database $DatabaseName -Query "SELECT COUNT(*) FROM dbo.BankTransactions;")
        reconciliationCandidates = [int](Invoke-SqlText -Database $DatabaseName -Query "SELECT COUNT(*) FROM dbo.BankReconciliationCandidates;")
        journalImportFixtures = @(10, 100, 1000, 10000)
        debitFixtureAccountCode = $assetCode
        creditFixtureAccountCode = $liabilityCode
        capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    }

    $summaryPath = Join-Path $databaseDir "financial-benchmark-v2-clean-summary.json"
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    $summary | ConvertTo-Json -Depth 6
}
finally {
    Remove-Item -LiteralPath $schemaTemp -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extraSeedTemp -Force -ErrorAction SilentlyContinue
}
