param(
    [string]$ConnectionString,
    [string]$AdminUsername = "admin",
    [string]$AdminPassword = "Admin@123",
    [int]$PeriodId = 202601,
    [string]$PeriodStart = "2026-01-01",
    [string]$PeriodEnd = "2026-12-31",
    [int]$AccountCount = 120,
    [int]$JournalEntryCount = 30000,
    [int]$MinimumPostedEntries = 5000
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    $appSettingsPath = Join-Path $PSScriptRoot "..\..\API\appsettings.json"
    $fullAppSettingsPath = [System.IO.Path]::GetFullPath($appSettingsPath)
    if (-not (Test-Path $fullAppSettingsPath)) {
        throw "ConnectionString was not provided and appsettings was not found: $fullAppSettingsPath"
    }

    $json = Get-Content -Path $fullAppSettingsPath -Raw | ConvertFrom-Json
    $ConnectionString = $json.AppSettings.ConnectionStrings
    if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
        throw "ConnectionString was not provided and AppSettings.ConnectionStrings is empty."
    }
}

function New-SqlCommand {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 1200
    return $command
}

function Add-Parameters {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlCommand]$Command,

        [hashtable]$Parameters
    )

    if ($null -eq $Parameters) {
        return
    }

    foreach ($entry in $Parameters.GetEnumerator()) {
        $name = $entry.Key
        $value = $entry.Value

        if ($value -is [System.Data.SqlClient.SqlParameter]) {
            $null = $Command.Parameters.Add($value)
            continue
        }

        if ($null -eq $value) {
            $null = $Command.Parameters.AddWithValue($name, [DBNull]::Value)
            continue
        }

        $null = $Command.Parameters.AddWithValue($name, $value)
    }
}

function Invoke-SqlNonQuery {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql,
        [hashtable]$Parameters
    )

    $command = New-SqlCommand -Connection $Connection -Sql $Sql
    Add-Parameters -Command $command -Parameters $Parameters
    $null = $command.ExecuteNonQuery()
}

function Invoke-SqlScalar {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql,
        [hashtable]$Parameters
    )

    $command = New-SqlCommand -Connection $Connection -Sql $Sql
    Add-Parameters -Command $command -Parameters $Parameters
    return $command.ExecuteScalar()
}

function Invoke-SqlRow {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql,
        [hashtable]$Parameters
    )

    $command = New-SqlCommand -Connection $Connection -Sql $Sql
    Add-Parameters -Command $command -Parameters $Parameters
    $reader = $command.ExecuteReader()

    try {
        if (-not $reader.Read()) {
            return $null
        }

        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $name = $reader.GetName($i)
            $value = $reader.GetValue($i)
            $row[$name] = if ($value -eq [DBNull]::Value) { $null } else { $value }
        }

        return $row
    }
    finally {
        $reader.Close()
    }
}

Write-Host "Seeding financial test data using connection string target."
$connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$connection.Open()

try {
    Invoke-SqlNonQuery -Connection $connection -Sql @"
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Admin')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Admin', N'System administrator role');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'User')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'User', N'Default application user role');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Auditor')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Auditor', N'Read-only financial audit role');
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'FinanceManager')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'FinanceManager', N'Financial operations manager role');
"@

    $hmac = New-Object System.Security.Cryptography.HMACSHA512
    $passwordSalt = $hmac.Key
    $passwordHash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($AdminPassword))
    $hmac.Dispose()

    $email = "$AdminUsername@local.invalid"
    $upsertUserSql = @"
DECLARE @ExistingUserId uniqueidentifier;
SELECT TOP 1 @ExistingUserId = UserId
FROM dbo.Users
WHERE Username = @Username OR Email = @Email;

IF @ExistingUserId IS NULL
BEGIN
    SET @ExistingUserId = NEWID();
    INSERT INTO dbo.Users
    (
        UserId, Username, Email, IsActive, RoleId, PasswordHash, PasswordSalt,
        FullName, DisplayName, PhoneNumber, ProfileUrl, LastAcvite,
        CreatedBy, UpdatedBy, CreatedAt, UpdatedAt, ActiveFlag
    )
    VALUES
    (
        @ExistingUserId, @Username, @Email, 1, NULL, @PasswordHash, @PasswordSalt,
        @Username, @Username, N'', N'', NULL,
        N'seed-test-data', N'seed-test-data', SYSUTCDATETIME(), SYSUTCDATETIME(), 1
    );
END
ELSE
BEGIN
    UPDATE dbo.Users
    SET Username = @Username,
        Email = @Email,
        IsActive = 1,
        ActiveFlag = 1,
        PasswordHash = @PasswordHash,
        PasswordSalt = @PasswordSalt,
        UpdatedBy = N'seed-test-data',
        UpdatedAt = SYSUTCDATETIME()
    WHERE UserId = @ExistingUserId;
END;

SELECT @ExistingUserId;
"@

    $hashParam = New-Object System.Data.SqlClient.SqlParameter("@PasswordHash", [System.Data.SqlDbType]::VarBinary, -1)
    $hashParam.Value = $passwordHash
    $saltParam = New-Object System.Data.SqlClient.SqlParameter("@PasswordSalt", [System.Data.SqlDbType]::VarBinary, -1)
    $saltParam.Value = $passwordSalt

    $adminUserIdObj = Invoke-SqlScalar -Connection $connection -Sql $upsertUserSql -Parameters @{
        "@Username" = $AdminUsername
        "@Email" = $email
        "@PasswordHash" = $hashParam
        "@PasswordSalt" = $saltParam
    }

    if ($null -eq $adminUserIdObj) {
        throw "Failed to resolve admin user id after upsert."
    }
    $adminUserId = [Guid]$adminUserIdObj

    Invoke-SqlNonQuery -Connection $connection -Sql @"
DECLARE @AdminRoleId int = (SELECT RoleId FROM dbo.Roles WHERE RoleName = N'Admin');
DECLARE @FinanceManagerRoleId int = (SELECT RoleId FROM dbo.Roles WHERE RoleName = N'FinanceManager');

IF @AdminRoleId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.UserRoles WHERE UserId = @UserId AND RoleId = @AdminRoleId)
    INSERT INTO dbo.UserRoles (UserId, RoleId) VALUES (@UserId, @AdminRoleId);

IF @FinanceManagerRoleId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.UserRoles WHERE UserId = @UserId AND RoleId = @FinanceManagerRoleId)
    INSERT INTO dbo.UserRoles (UserId, RoleId) VALUES (@UserId, @FinanceManagerRoleId);
"@ -Parameters @{
        "@UserId" = $adminUserId
    }

    Invoke-SqlNonQuery -Connection $connection -Sql @"
IF NOT EXISTS (SELECT 1 FROM dbo.AccountingPeriods WHERE PeriodId = @PeriodId)
BEGIN
    INSERT INTO dbo.AccountingPeriods (PeriodId, StartDate, EndDate, IsClosed, ClosedAt, ClosedByUserId)
    VALUES (@PeriodId, @StartDate, @EndDate, 0, NULL, NULL);
END
ELSE
BEGIN
    UPDATE dbo.AccountingPeriods
    SET StartDate = @StartDate,
        EndDate = @EndDate,
        IsClosed = 0,
        ClosedAt = NULL,
        ClosedByUserId = NULL
    WHERE PeriodId = @PeriodId;
END;
"@ -Parameters @{
        "@PeriodId" = $PeriodId
        "@StartDate" = [DateTime]$PeriodStart
        "@EndDate" = [DateTime]$PeriodEnd
    }

    $accountStats = Invoke-SqlRow -Connection $connection -Sql "SELECT COUNT(*) AS AccountCount FROM dbo.ChartOfAccounts;"
    $currentAccountCount = [int]$accountStats["AccountCount"]
    $accountsToCreate = [Math]::Max(0, $AccountCount - $currentAccountCount)

    if ($accountsToCreate -gt 0) {
        Invoke-SqlNonQuery -Connection $connection -Sql @"
DECLARE @BaseNumber int =
(
    SELECT ISNULL(
        MAX(CASE
            WHEN LEN(AccountCode) >= 7
             AND TRY_CONVERT(int, RIGHT(AccountCode, 6)) IS NOT NULL
            THEN TRY_CONVERT(int, RIGHT(AccountCode, 6))
            ELSE NULL
        END),
    0)
    FROM dbo.ChartOfAccounts
);

;WITH N AS
(
    SELECT TOP (@Need)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.ChartOfAccounts (AccountCode, AccountName, AccountType, IsActive, CreatedAt, UpdatedAt)
SELECT
    CASE ((n - 1) % 5)
        WHEN 0 THEN CONCAT(N'A', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 1 THEN CONCAT(N'L', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 2 THEN CONCAT(N'E', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 3 THEN CONCAT(N'R', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        ELSE CONCAT(N'X', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
    END AS AccountCode,
    CASE ((n - 1) % 5)
        WHEN 0 THEN CONCAT(N'Seed Asset ', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 1 THEN CONCAT(N'Seed Liability ', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 2 THEN CONCAT(N'Seed Equity ', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        WHEN 3 THEN CONCAT(N'Seed Revenue ', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
        ELSE CONCAT(N'Seed Expense ', RIGHT(N'000000' + CONVERT(nvarchar(6), @BaseNumber + n), 6))
    END AS AccountName,
    CASE ((n - 1) % 5)
        WHEN 0 THEN N'Asset'
        WHEN 1 THEN N'Liability'
        WHEN 2 THEN N'Equity'
        WHEN 3 THEN N'Revenue'
        ELSE N'Expense'
    END AS AccountType,
    1,
    SYSUTCDATETIME(),
    SYSUTCDATETIME()
FROM N;
"@ -Parameters @{
            "@Need" = $accountsToCreate
        }
    }

    $accountIds = Invoke-SqlRow -Connection $connection -Sql @"
SELECT
    (SELECT TOP 1 AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Asset' AND IsActive = 1 ORDER BY AccountId) AS AssetAccountId,
    (SELECT TOP 1 AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Liability' AND IsActive = 1 ORDER BY AccountId) AS LiabilityAccountId,
    (SELECT TOP 1 AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Equity' AND IsActive = 1 ORDER BY AccountId) AS EquityAccountId,
    (SELECT TOP 1 AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Revenue' AND IsActive = 1 ORDER BY AccountId) AS RevenueAccountId,
    (SELECT TOP 1 AccountId FROM dbo.ChartOfAccounts WHERE AccountType = N'Expense' AND IsActive = 1 ORDER BY AccountId) AS ExpenseAccountId;
"@

    foreach ($requiredKey in @("AssetAccountId", "LiabilityAccountId", "EquityAccountId", "RevenueAccountId", "ExpenseAccountId")) {
        if ($null -eq $accountIds[$requiredKey]) {
            throw "Missing required account type for seeding: $requiredKey"
        }
    }

    $entryStats = Invoke-SqlRow -Connection $connection -Sql @"
SELECT
    COUNT(*) AS TotalEntries,
    SUM(CASE WHEN Status = N'Posted' THEN 1 ELSE 0 END) AS PostedEntries
FROM dbo.JournalEntries;
"@
    $currentTotalEntries = [int]$entryStats["TotalEntries"]
    $currentPostedEntries = if ($null -eq $entryStats["PostedEntries"]) { 0 } else { [int]$entryStats["PostedEntries"] }

    $missingTotalEntries = [Math]::Max(0, $JournalEntryCount - $currentTotalEntries)
    $missingPostedEntries = [Math]::Max(0, $MinimumPostedEntries - $currentPostedEntries)

    $entriesToCreate = [Math]::Max($missingTotalEntries, $missingPostedEntries)
    $postedToCreate = [Math]::Min($entriesToCreate, $missingPostedEntries)

    if ($entriesToCreate -gt 0) {
        Invoke-SqlNonQuery -Connection $connection -Sql @"
DECLARE @PeriodStartDate date;
DECLARE @PeriodEndDate date;
SELECT @PeriodStartDate = StartDate, @PeriodEndDate = EndDate
FROM dbo.AccountingPeriods
WHERE PeriodId = @PeriodId;

IF @PeriodStartDate IS NULL OR @PeriodEndDate IS NULL
    THROW 50000, 'Accounting period was not found for seeding journal entries.', 1;

DECLARE @DateSpan int = DATEDIFF(DAY, @PeriodStartDate, @PeriodEndDate) + 1;
IF @DateSpan < 1 SET @DateSpan = 1;

DECLARE @PostedToCreate int = CASE WHEN @TargetPosted > @TargetTotal THEN @TargetTotal ELSE @TargetPosted END;
DECLARE @DraftToCreate int = @TargetTotal - @PostedToCreate;

CREATE TABLE #NewEntries
(
    JournalEntryId bigint NOT NULL,
    IsPosted bit NOT NULL
);

IF @PostedToCreate > 0
BEGIN
    ;WITH N AS
    (
        SELECT TOP (@PostedToCreate)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO dbo.JournalEntries
    (
        EntryDate, Description, ReferenceNo, Status,
        CreatedByUserId, CreatedAt, PostedAt, ReversedAt
    )
    OUTPUT INSERTED.JournalEntryId, CAST(1 AS bit) INTO #NewEntries (JournalEntryId, IsPosted)
    SELECT
        DATEADD(DAY, -((n - 1) % @DateSpan), @PeriodEndDate),
        CONCAT(N'Seed posted entry ', n),
        CONCAT(N'SEED-P-', RIGHT(N'00000000' + CONVERT(nvarchar(8), n), 8), N'-', CONVERT(nvarchar(8), @PeriodId)),
        N'Posted',
        @CreatedByUserId,
        SYSUTCDATETIME(),
        SYSUTCDATETIME(),
        NULL
    FROM N;
END;

IF @DraftToCreate > 0
BEGIN
    ;WITH N AS
    (
        SELECT TOP (@DraftToCreate)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b
    )
    INSERT INTO dbo.JournalEntries
    (
        EntryDate, Description, ReferenceNo, Status,
        CreatedByUserId, CreatedAt, PostedAt, ReversedAt
    )
    OUTPUT INSERTED.JournalEntryId, CAST(0 AS bit) INTO #NewEntries (JournalEntryId, IsPosted)
    SELECT
        DATEADD(DAY, -((n - 1) % @DateSpan), @PeriodEndDate),
        CONCAT(N'Seed draft entry ', n),
        CONCAT(N'SEED-D-', RIGHT(N'00000000' + CONVERT(nvarchar(8), n), 8), N'-', CONVERT(nvarchar(8), @PeriodId)),
        N'Draft',
        @CreatedByUserId,
        SYSUTCDATETIME(),
        NULL,
        NULL
    FROM N;
END;

SELECT
    JournalEntryId,
    IsPosted,
    CAST(((ABS(CHECKSUM(JournalEntryId)) % 90000) + 1000) / 100.0 AS decimal(18,2)) AS Amount,
    ABS(CHECKSUM(JournalEntryId, 97)) % 3 AS Pattern
INTO #EntryAmounts
FROM #NewEntries;

INSERT INTO dbo.JournalEntryLines (JournalEntryId, AccountId, LineDescription, Debit, Credit)
SELECT
    JournalEntryId,
    CASE
        WHEN IsPosted = 1 AND Pattern = 0 THEN @ExpenseAccountId
        ELSE @AssetAccountId
    END,
    N'Seed debit line',
    Amount,
    0
FROM #EntryAmounts;

INSERT INTO dbo.JournalEntryLines (JournalEntryId, AccountId, LineDescription, Debit, Credit)
SELECT
    JournalEntryId,
    CASE
        WHEN IsPosted = 1 AND Pattern = 0 THEN @RevenueAccountId
        WHEN IsPosted = 1 AND Pattern = 1 THEN @LiabilityAccountId
        WHEN IsPosted = 1 AND Pattern = 2 THEN @EquityAccountId
        ELSE @LiabilityAccountId
    END,
    N'Seed credit line',
    0,
    Amount
FROM #EntryAmounts;
"@ -Parameters @{
            "@PeriodId" = $PeriodId
            "@TargetTotal" = $entriesToCreate
            "@TargetPosted" = $postedToCreate
            "@CreatedByUserId" = $adminUserId
            "@AssetAccountId" = [int]$accountIds["AssetAccountId"]
            "@LiabilityAccountId" = [int]$accountIds["LiabilityAccountId"]
            "@EquityAccountId" = [int]$accountIds["EquityAccountId"]
            "@RevenueAccountId" = [int]$accountIds["RevenueAccountId"]
            "@ExpenseAccountId" = [int]$accountIds["ExpenseAccountId"]
        }
    }

    $finalAccountCount = [int](Invoke-SqlScalar -Connection $connection -Sql "SELECT COUNT(*) FROM dbo.ChartOfAccounts;")
    $finalEntryStats = Invoke-SqlRow -Connection $connection -Sql @"
SELECT
    COUNT(*) AS TotalEntries,
    SUM(CASE WHEN Status = N'Posted' THEN 1 ELSE 0 END) AS PostedEntries
FROM dbo.JournalEntries;
"@

    $finalTotalEntries = [int]$finalEntryStats["TotalEntries"]
    $finalPostedEntries = if ($null -eq $finalEntryStats["PostedEntries"]) { 0 } else { [int]$finalEntryStats["PostedEntries"] }

    Write-Host "Seed completed."
    Write-Host "Admin user: $AdminUsername ($adminUserId)"
    Write-Host "Period: $PeriodId"
    Write-Host "Accounts: $finalAccountCount"
    Write-Host "Journal entries: $finalTotalEntries (posted: $finalPostedEntries)"

    [pscustomobject]@{
        AdminUsername = $AdminUsername
        AdminUserId = $adminUserId
        PeriodId = $PeriodId
        AccountCount = $finalAccountCount
        TotalJournalEntries = $finalTotalEntries
        PostedJournalEntries = $finalPostedEntries
        DefaultAccountId = [int]$accountIds["AssetAccountId"]
    }
}
finally {
    $connection.Close()
    $connection.Dispose()
}
