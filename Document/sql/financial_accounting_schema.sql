SET NOCOUNT ON;

IF DB_ID(N'Financial') IS NULL
BEGIN
    CREATE DATABASE [Financial];
END;
GO

USE [Financial];
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users
    (
        UserId uniqueidentifier NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        Username nvarchar(100) NOT NULL,
        Email nvarchar(200) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        RoleId uniqueidentifier NULL,
        PasswordHash varbinary(max) NOT NULL,
        PasswordSalt varbinary(max) NOT NULL,
        FullName nvarchar(200) NOT NULL CONSTRAINT DF_Users_FullName DEFAULT (N''),
        DisplayName nvarchar(200) NULL,
        PhoneNumber nvarchar(30) NOT NULL CONSTRAINT DF_Users_PhoneNumber DEFAULT (N''),
        ProfileUrl nvarchar(500) NOT NULL CONSTRAINT DF_Users_ProfileUrl DEFAULT (N''),
        LastAcvite datetime2 NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Users_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Users_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Users_ActiveFlag DEFAULT (1)
    );
END;
GO

IF COL_LENGTH(N'dbo.Users', N'Username') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD Username nvarchar(100) NULL;
END;
GO

IF COL_LENGTH(N'dbo.Users', N'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD IsActive bit NOT NULL CONSTRAINT DF_Users_IsActive_Auto DEFAULT (1);
END;
GO

IF COL_LENGTH(N'dbo.Users', N'FullName') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD FullName nvarchar(200) NOT NULL CONSTRAINT DF_Users_FullName_Auto DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'DisplayName') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD DisplayName nvarchar(200) NULL;
END;
GO

IF COL_LENGTH(N'dbo.Users', N'PhoneNumber') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD PhoneNumber nvarchar(30) NOT NULL CONSTRAINT DF_Users_PhoneNumber_Auto DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'ProfileUrl') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD ProfileUrl nvarchar(500) NOT NULL CONSTRAINT DF_Users_ProfileUrl_Auto DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'CreatedBy') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Users_CreatedBy_Auto DEFAULT (N'System');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'UpdatedBy') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Users_UpdatedBy_Auto DEFAULT (N'System');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'CreatedAt') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD CreatedAt datetime2 NOT NULL CONSTRAINT DF_Users_CreatedAt_Auto DEFAULT SYSUTCDATETIME();
END;
GO

IF COL_LENGTH(N'dbo.Users', N'UpdatedAt') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Users_UpdatedAt_Auto DEFAULT SYSUTCDATETIME();
END;
GO

IF COL_LENGTH(N'dbo.Users', N'ActiveFlag') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD ActiveFlag bit NOT NULL CONSTRAINT DF_Users_ActiveFlag_Auto DEFAULT (1);
END;
GO

IF COL_LENGTH(N'dbo.Users', N'Email') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD Email nvarchar(200) NOT NULL CONSTRAINT DF_Users_Email_Auto DEFAULT (N'');
END;
GO

IF COL_LENGTH(N'dbo.Users', N'PasswordHash') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD PasswordHash varbinary(max) NOT NULL CONSTRAINT DF_Users_PasswordHash_Auto DEFAULT (0x00);
END;
GO

IF COL_LENGTH(N'dbo.Users', N'PasswordSalt') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD PasswordSalt varbinary(max) NOT NULL CONSTRAINT DF_Users_PasswordSalt_Auto DEFAULT (0x00);
END;
GO

IF COL_LENGTH(N'dbo.Users', N'LastAcvite') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD LastAcvite datetime2 NULL;
END;
GO

IF COL_LENGTH(N'dbo.Users', N'RoleId') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD RoleId uniqueidentifier NULL;
END;
GO

UPDATE dbo.Users
SET Username = CASE
    WHEN NULLIF(LTRIM(RTRIM(Username)), N'') IS NOT NULL THEN LTRIM(RTRIM(Username))
    WHEN NULLIF(LTRIM(RTRIM(Email)), N'') IS NOT NULL THEN LTRIM(RTRIM(Email))
    ELSE N'user_' + RIGHT(REPLACE(CONVERT(nvarchar(36), UserId), N'-', N''), 12)
END
WHERE Username IS NULL OR LTRIM(RTRIM(Username)) = N'';
GO

;WITH DuplicateUsernames AS
(
    SELECT UserId, Username, ROW_NUMBER() OVER (PARTITION BY Username ORDER BY UserId) AS rn
    FROM dbo.Users
)
UPDATE u
SET Username = CONCAT(u.Username, N'_', RIGHT(REPLACE(CONVERT(nvarchar(36), u.UserId), N'-', N''), 8))
FROM dbo.Users u
JOIN DuplicateUsernames d ON d.UserId = u.UserId
WHERE d.rn > 1;
GO

UPDATE dbo.Users
SET Email = N'user_' + RIGHT(REPLACE(CONVERT(nvarchar(36), UserId), N'-', N''), 12) + N'@local.invalid'
WHERE Email IS NULL OR LTRIM(RTRIM(Email)) = N'';
GO

;WITH DuplicateEmails AS
(
    SELECT UserId, Email, ROW_NUMBER() OVER (PARTITION BY Email ORDER BY UserId) AS rn
    FROM dbo.Users
)
UPDATE u
SET Email = CONCAT(N'dup_', RIGHT(REPLACE(CONVERT(nvarchar(36), u.UserId), N'-', N''), 12), N'@local.invalid')
FROM dbo.Users u
JOIN DuplicateEmails d ON d.UserId = u.UserId
WHERE d.rn > 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Username')
BEGIN
    CREATE UNIQUE INDEX UX_Users_Username ON dbo.Users(Username);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'UX_Users_Email')
BEGIN
    CREATE UNIQUE INDEX UX_Users_Email ON dbo.Users(Email);
END;
GO

IF OBJECT_ID(N'dbo.Role', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Role
    (
        RoleId uniqueidentifier NOT NULL CONSTRAINT PK_Role PRIMARY KEY,
        RoleName nvarchar(50) NOT NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Role_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Role_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_Role_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Role_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Role_ActiveFlag DEFAULT (1)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleId = 'E2A3172D-8E4A-4B98-8CFA-1F25B0ED0A31')
BEGIN
    INSERT INTO dbo.Role (RoleId, RoleName)
    VALUES ('E2A3172D-8E4A-4B98-8CFA-1F25B0ED0A31', N'User');
END;
GO

IF OBJECT_ID(N'dbo.Log', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Log
    (
        LogId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Log PRIMARY KEY,
        UserName nvarchar(200) NULL,
        UserId int NOT NULL CONSTRAINT DF_Log_UserId DEFAULT (0),
        IP nvarchar(50) NULL,
        LaptopModel nvarchar(200) NULL,
        Description nvarchar(max) NULL,
        LogType nvarchar(50) NULL,
        MethodName nvarchar(100) NULL,
        Exception nvarchar(max) NULL,
        LogTrace nvarchar(max) NULL,
        CreateDate datetime2 NOT NULL CONSTRAINT DF_Log_CreateDate DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Log_ActiveFlag DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Todo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Todo
    (
        ID uniqueidentifier NOT NULL CONSTRAINT PK_Todo PRIMARY KEY,
        Title nvarchar(500) NULL,
        Description nvarchar(max) NULL,
        Status nvarchar(50) NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Todo_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Todo_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_Todo_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Todo_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Todo_ActiveFlag DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Lexicon', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Lexicon
    (
        LexiconID uniqueidentifier NOT NULL CONSTRAINT PK_Lexicon PRIMARY KEY,
        LexiconName nvarchar(500) NULL,
        LexiconRewrite nvarchar(max) NULL,
        Language nvarchar(50) NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Lexicon_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Lexicon_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_Lexicon_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Lexicon_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Lexicon_ActiveFlag DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.TextToSpeechHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TextToSpeechHistory
    (
        TextToSpeechID uniqueidentifier NOT NULL CONSTRAINT PK_TextToSpeechHistory PRIMARY KEY,
        Title nvarchar(500) NULL,
        [Text] nvarchar(max) NULL,
        Url nvarchar(max) NULL,
        ObjSegments nvarchar(max) NULL,
        ObjAlias nvarchar(max) NULL,
        TextSSML nvarchar(max) NULL,
        Language nvarchar(50) NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_TextToSpeechHistory_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_TextToSpeechHistory_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_TextToSpeechHistory_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_TextToSpeechHistory_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_TextToSpeechHistory_ActiveFlag DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Quotation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Quotation
    (
        ID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Quotation PRIMARY KEY,
        Code nvarchar(50) NULL,
        Grandtotal decimal(18,2) NULL,
        Subtotal decimal(18,2) NULL,
        Customer nvarchar(200) NULL,
        Seller nvarchar(200) NULL,
        Vatamount decimal(18,2) NULL,
        CreatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Quotation_CreatedBy DEFAULT (N'System'),
        UpdatedBy nvarchar(100) NOT NULL CONSTRAINT DF_Quotation_UpdatedBy DEFAULT (N'System'),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_Quotation_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_Quotation_UpdatedAt DEFAULT SYSUTCDATETIME(),
        ActiveFlag bit NOT NULL CONSTRAINT DF_Quotation_ActiveFlag DEFAULT (1)
    );
END;
GO

IF OBJECT_ID(N'dbo.Roles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Roles
    (
        RoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
        RoleName nvarchar(50) NOT NULL,
        Description nvarchar(200) NULL
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Roles') AND name = N'UX_Roles_RoleName')
BEGIN
    CREATE UNIQUE INDEX UX_Roles_RoleName ON dbo.Roles(RoleName);
END;
GO

IF OBJECT_ID(N'dbo.UserRoles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserRoles
    (
        UserRoleId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserRoles PRIMARY KEY,
        UserId uniqueidentifier NOT NULL,
        RoleId int NOT NULL,
        CONSTRAINT FK_UserRoles_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE,
        CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.UserRoles') AND name = N'UX_UserRoles_UserRole')
BEGIN
    CREATE UNIQUE INDEX UX_UserRoles_UserRole ON dbo.UserRoles(UserId, RoleId);
END;
GO

IF OBJECT_ID(N'dbo.ChartOfAccounts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChartOfAccounts
    (
        AccountId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChartOfAccounts PRIMARY KEY,
        AccountCode nvarchar(20) NOT NULL,
        AccountName nvarchar(200) NOT NULL,
        AccountType nvarchar(20) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_ChartOfAccounts_IsActive DEFAULT (1),
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_ChartOfAccounts_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_ChartOfAccounts_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ChartOfAccounts') AND name = N'UX_ChartOfAccounts_AccountCode')
BEGIN
    CREATE UNIQUE INDEX UX_ChartOfAccounts_AccountCode ON dbo.ChartOfAccounts(AccountCode);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ChartOfAccounts') AND name = N'IX_ChartOfAccounts_AccountType')
BEGIN
    CREATE INDEX IX_ChartOfAccounts_AccountType ON dbo.ChartOfAccounts(AccountType);
END;
GO

IF OBJECT_ID(N'dbo.JournalImportBatches', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalImportBatches
    (
        ImportId uniqueidentifier NOT NULL CONSTRAINT PK_JournalImportBatches PRIMARY KEY,
        CreatedByUserId uniqueidentifier NOT NULL,
        IdempotencyKey nvarchar(100) NOT NULL,
        FileName nvarchar(260) NOT NULL,
        Atomic bit NOT NULL,
        Status nvarchar(20) NOT NULL,
        TotalRows int NOT NULL,
        ValidRows int NOT NULL,
        InvalidRows int NOT NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_JournalImportBatches_CreatedAt DEFAULT SYSUTCDATETIME(),
        CommittedAt datetime2 NULL
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalImportBatches') AND name = N'UX_JournalImportBatches_UserKey')
BEGIN
    CREATE UNIQUE INDEX UX_JournalImportBatches_UserKey
        ON dbo.JournalImportBatches(CreatedByUserId, IdempotencyKey);
END;
GO

IF OBJECT_ID(N'dbo.JournalEntries', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalEntries
    (
        JournalEntryId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JournalEntries PRIMARY KEY,
        EntryDate date NOT NULL,
        Description nvarchar(500) NULL,
        ReferenceNo nvarchar(100) NULL,
        Status nvarchar(20) NOT NULL CONSTRAINT DF_JournalEntries_Status DEFAULT (N'Draft'),
        CreatedByUserId uniqueidentifier NOT NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_JournalEntries_CreatedAt DEFAULT SYSUTCDATETIME(),
        PostedAt datetime2 NULL,
        ReversedAt datetime2 NULL,
        ImportBatchId uniqueidentifier NULL,
        CONSTRAINT FK_JournalEntries_Users FOREIGN KEY (CreatedByUserId) REFERENCES dbo.Users(UserId),
        CONSTRAINT FK_JournalEntries_JournalImportBatches FOREIGN KEY (ImportBatchId) REFERENCES dbo.JournalImportBatches(ImportId) ON DELETE SET NULL
    );
END;
GO

IF COL_LENGTH(N'dbo.JournalEntries', N'ImportBatchId') IS NULL
BEGIN
    ALTER TABLE dbo.JournalEntries ADD ImportBatchId uniqueidentifier NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_JournalEntries_JournalImportBatches')
BEGIN
    ALTER TABLE dbo.JournalEntries
        ADD CONSTRAINT FK_JournalEntries_JournalImportBatches
        FOREIGN KEY (ImportBatchId) REFERENCES dbo.JournalImportBatches(ImportId) ON DELETE SET NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalEntries') AND name = N'IX_JournalEntries_EntryDate')
BEGIN
    CREATE INDEX IX_JournalEntries_EntryDate ON dbo.JournalEntries(EntryDate);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalEntries') AND name = N'IX_JournalEntries_ReferenceNo')
BEGIN
    CREATE INDEX IX_JournalEntries_ReferenceNo ON dbo.JournalEntries(ReferenceNo);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalEntries') AND name = N'IX_JournalEntries_Status')
BEGIN
    CREATE INDEX IX_JournalEntries_Status ON dbo.JournalEntries(Status);
END;
GO

IF OBJECT_ID(N'dbo.JournalEntryLines', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalEntryLines
    (
        JournalEntryLineId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JournalEntryLines PRIMARY KEY,
        JournalEntryId bigint NOT NULL,
        AccountId int NOT NULL,
        LineDescription nvarchar(500) NULL,
        Debit decimal(18,2) NOT NULL CONSTRAINT DF_JournalEntryLines_Debit DEFAULT (0),
        Credit decimal(18,2) NOT NULL CONSTRAINT DF_JournalEntryLines_Credit DEFAULT (0),
        CONSTRAINT FK_JournalEntryLines_JournalEntries FOREIGN KEY (JournalEntryId) REFERENCES dbo.JournalEntries(JournalEntryId) ON DELETE CASCADE,
        CONSTRAINT FK_JournalEntryLines_ChartOfAccounts FOREIGN KEY (AccountId) REFERENCES dbo.ChartOfAccounts(AccountId),
        CONSTRAINT CK_JournalEntryLines_DebitCredit CHECK ((Debit >= 0 AND Credit >= 0) AND ((CASE WHEN Debit > 0 THEN 1 ELSE 0 END + CASE WHEN Credit > 0 THEN 1 ELSE 0 END) = 1))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalEntryLines') AND name = N'IX_JournalEntryLines_JournalEntryId')
BEGIN
    CREATE INDEX IX_JournalEntryLines_JournalEntryId ON dbo.JournalEntryLines(JournalEntryId);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalEntryLines') AND name = N'IX_JournalEntryLines_AccountId')
BEGIN
    CREATE INDEX IX_JournalEntryLines_AccountId ON dbo.JournalEntryLines(AccountId);
END;
GO

IF OBJECT_ID(N'dbo.JournalImportRows', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.JournalImportRows
    (
        JournalImportRowId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_JournalImportRows PRIMARY KEY,
        ImportId uniqueidentifier NOT NULL,
        RowNumber int NOT NULL,
        EntryReference nvarchar(100) NOT NULL,
        EntryDate datetime2 NULL,
        Description nvarchar(500) NULL,
        AccountCode nvarchar(20) NOT NULL,
        AccountId int NULL,
        Debit decimal(18,2) NOT NULL,
        Credit decimal(18,2) NOT NULL,
        IsValid bit NOT NULL,
        Error nvarchar(1000) NULL,
        CONSTRAINT FK_JournalImportRows_JournalImportBatches FOREIGN KEY (ImportId) REFERENCES dbo.JournalImportBatches(ImportId) ON DELETE CASCADE,
        CONSTRAINT FK_JournalImportRows_ChartOfAccounts FOREIGN KEY (AccountId) REFERENCES dbo.ChartOfAccounts(AccountId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.JournalImportRows') AND name = N'UX_JournalImportRows_ImportRow')
BEGIN
    CREATE UNIQUE INDEX UX_JournalImportRows_ImportRow
        ON dbo.JournalImportRows(ImportId, RowNumber);
END;
GO

IF OBJECT_ID(N'dbo.AccountingPeriods', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AccountingPeriods
    (
        PeriodId int NOT NULL CONSTRAINT PK_AccountingPeriods PRIMARY KEY,
        StartDate date NOT NULL,
        EndDate date NOT NULL,
        IsClosed bit NOT NULL CONSTRAINT DF_AccountingPeriods_IsClosed DEFAULT (0),
        ClosedAt datetime2 NULL,
        ClosedByUserId uniqueidentifier NULL,
        CloseRequestId uniqueidentifier NULL,
        Version int NOT NULL CONSTRAINT DF_AccountingPeriods_Version DEFAULT (1),
        CONSTRAINT FK_AccountingPeriods_Users FOREIGN KEY (ClosedByUserId) REFERENCES dbo.Users(UserId)
    );
END;
GO

IF COL_LENGTH(N'dbo.AccountingPeriods', N'CloseRequestId') IS NULL
BEGIN
    ALTER TABLE dbo.AccountingPeriods ADD CloseRequestId uniqueidentifier NULL;
END;
GO

IF COL_LENGTH(N'dbo.AccountingPeriods', N'Version') IS NULL
BEGIN
    ALTER TABLE dbo.AccountingPeriods
        ADD Version int NOT NULL CONSTRAINT DF_AccountingPeriods_Version_Auto DEFAULT (1);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AccountingPeriods') AND name = N'IX_AccountingPeriods_IsClosed')
BEGIN
    CREATE INDEX IX_AccountingPeriods_IsClosed ON dbo.AccountingPeriods(IsClosed);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AccountingPeriods') AND name = N'UX_AccountingPeriods_CloseRequestId')
BEGIN
    CREATE UNIQUE INDEX UX_AccountingPeriods_CloseRequestId
        ON dbo.AccountingPeriods(CloseRequestId)
        WHERE CloseRequestId IS NOT NULL;
END;
GO

IF OBJECT_ID(N'dbo.BankReconciliations', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankReconciliations
    (
        ReconciliationId uniqueidentifier NOT NULL CONSTRAINT PK_BankReconciliations PRIMARY KEY,
        PeriodId int NOT NULL,
        BankAccountId int NOT NULL,
        DateFrom date NOT NULL,
        DateTo date NOT NULL,
        Status nvarchar(20) NOT NULL,
        CreatedByUserId uniqueidentifier NOT NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_BankReconciliations_CreatedAt DEFAULT SYSUTCDATETIME(),
        FinalizedAt datetime2 NULL,
        FinalizeRequestId uniqueidentifier NULL,
        Version int NOT NULL CONSTRAINT DF_BankReconciliations_Version DEFAULT (1),
        CONSTRAINT FK_BankReconciliations_AccountingPeriods FOREIGN KEY (PeriodId) REFERENCES dbo.AccountingPeriods(PeriodId),
        CONSTRAINT FK_BankReconciliations_ChartOfAccounts FOREIGN KEY (BankAccountId) REFERENCES dbo.ChartOfAccounts(AccountId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BankReconciliations') AND name = N'IX_BankReconciliations_PeriodAccountStatus')
BEGIN
    CREATE INDEX IX_BankReconciliations_PeriodAccountStatus
        ON dbo.BankReconciliations(PeriodId, BankAccountId, Status);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BankReconciliations') AND name = N'UX_BankReconciliations_FinalizeRequestId')
BEGIN
    CREATE UNIQUE INDEX UX_BankReconciliations_FinalizeRequestId
        ON dbo.BankReconciliations(FinalizeRequestId)
        WHERE FinalizeRequestId IS NOT NULL;
END;
GO

IF OBJECT_ID(N'dbo.BankTransactions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankTransactions
    (
        BankTransactionId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_BankTransactions PRIMARY KEY,
        ReconciliationId uniqueidentifier NOT NULL,
        TransactionDate date NOT NULL,
        Amount decimal(18,2) NOT NULL,
        ReferenceNo nvarchar(100) NULL,
        Description nvarchar(500) NULL,
        MatchStatus nvarchar(20) NOT NULL,
        MatchedJournalEntryId bigint NULL,
        CONSTRAINT FK_BankTransactions_BankReconciliations FOREIGN KEY (ReconciliationId) REFERENCES dbo.BankReconciliations(ReconciliationId) ON DELETE CASCADE,
        CONSTRAINT FK_BankTransactions_JournalEntries FOREIGN KEY (MatchedJournalEntryId) REFERENCES dbo.JournalEntries(JournalEntryId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BankTransactions') AND name = N'IX_BankTransactions_ReconciliationStatus')
BEGIN
    CREATE INDEX IX_BankTransactions_ReconciliationStatus
        ON dbo.BankTransactions(ReconciliationId, MatchStatus);
END;
GO

IF OBJECT_ID(N'dbo.BankReconciliationCandidates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankReconciliationCandidates
    (
        BankReconciliationCandidateId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_BankReconciliationCandidates PRIMARY KEY,
        BankTransactionId bigint NOT NULL,
        JournalEntryId bigint NOT NULL,
        Score int NOT NULL,
        IsSelected bit NOT NULL,
        CONSTRAINT FK_BankReconciliationCandidates_BankTransactions FOREIGN KEY (BankTransactionId) REFERENCES dbo.BankTransactions(BankTransactionId) ON DELETE CASCADE,
        CONSTRAINT FK_BankReconciliationCandidates_JournalEntries FOREIGN KEY (JournalEntryId) REFERENCES dbo.JournalEntries(JournalEntryId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BankReconciliationCandidates') AND name = N'UX_BankReconciliationCandidates_TransactionEntry')
BEGIN
    CREATE UNIQUE INDEX UX_BankReconciliationCandidates_TransactionEntry
        ON dbo.BankReconciliationCandidates(BankTransactionId, JournalEntryId);
END;
GO

IF OBJECT_ID(N'dbo.Currencies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Currencies
    (
        CurrencyCode nvarchar(10) NOT NULL CONSTRAINT PK_Currencies PRIMARY KEY,
        Name nvarchar(50) NOT NULL,
        Symbol nvarchar(10) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.Reports', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Reports
    (
        ReportId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Reports PRIMARY KEY,
        ReportType nvarchar(50) NOT NULL,
        PeriodId int NOT NULL,
        GeneratedByUserId uniqueidentifier NOT NULL,
        GeneratedAt datetime2 NOT NULL CONSTRAINT DF_Reports_GeneratedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Reports_AccountingPeriods FOREIGN KEY (PeriodId) REFERENCES dbo.AccountingPeriods(PeriodId),
        CONSTRAINT FK_Reports_Users FOREIGN KEY (GeneratedByUserId) REFERENCES dbo.Users(UserId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Reports') AND name = N'IX_Reports_ReportType')
BEGIN
    CREATE INDEX IX_Reports_ReportType ON dbo.Reports(ReportType);
END;
GO

IF OBJECT_ID(N'dbo.ReportItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ReportItems
    (
        ReportItemId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReportItems PRIMARY KEY,
        ReportId bigint NOT NULL,
        AccountId int NOT NULL,
        DebitTotal decimal(18,2) NOT NULL,
        CreditTotal decimal(18,2) NOT NULL,
        Balance decimal(18,2) NOT NULL,
        CONSTRAINT FK_ReportItems_Reports FOREIGN KEY (ReportId) REFERENCES dbo.Reports(ReportId) ON DELETE CASCADE,
        CONSTRAINT FK_ReportItems_ChartOfAccounts FOREIGN KEY (AccountId) REFERENCES dbo.ChartOfAccounts(AccountId)
    );
END;
GO

IF OBJECT_ID(N'dbo.LedgerBalances', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LedgerBalances
    (
        LedgerBalanceId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_LedgerBalances PRIMARY KEY,
        AccountId int NOT NULL,
        PeriodId int NOT NULL,
        DebitTotal decimal(18,2) NOT NULL,
        CreditTotal decimal(18,2) NOT NULL,
        Balance decimal(18,2) NOT NULL,
        UpdatedAt datetime2 NOT NULL CONSTRAINT DF_LedgerBalances_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_LedgerBalances_ChartOfAccounts FOREIGN KEY (AccountId) REFERENCES dbo.ChartOfAccounts(AccountId),
        CONSTRAINT FK_LedgerBalances_AccountingPeriods FOREIGN KEY (PeriodId) REFERENCES dbo.AccountingPeriods(PeriodId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.LedgerBalances') AND name = N'UX_LedgerBalances_AccountPeriod')
BEGIN
    CREATE UNIQUE INDEX UX_LedgerBalances_AccountPeriod ON dbo.LedgerBalances(AccountId, PeriodId);
END;
GO

IF OBJECT_ID(N'dbo.AuditLogs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLogs
    (
        AuditLogId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLogs PRIMARY KEY,
        UserId uniqueidentifier NULL,
        Action nvarchar(100) NOT NULL,
        EntityName nvarchar(100) NULL,
        EntityId nvarchar(50) NULL,
        [Timestamp] datetime2 NOT NULL CONSTRAINT DF_AuditLogs_Timestamp DEFAULT SYSUTCDATETIME(),
        IpAddress nvarchar(50) NULL,
        DetailsJson nvarchar(max) NULL,
        CONSTRAINT FK_AuditLogs_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AuditLogs') AND name = N'IX_AuditLogs_Action')
BEGIN
    CREATE INDEX IX_AuditLogs_Action ON dbo.AuditLogs(Action);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AuditLogs') AND name = N'IX_AuditLogs_Timestamp')
BEGIN
    CREATE INDEX IX_AuditLogs_Timestamp ON dbo.AuditLogs([Timestamp]);
END;
GO

IF OBJECT_ID(N'dbo.RefreshTokens', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RefreshTokens
    (
        RefreshTokenId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshTokens PRIMARY KEY,
        UserId uniqueidentifier NOT NULL,
        TokenHash nvarchar(500) NOT NULL,
        ExpiresAt datetime2 NOT NULL,
        RevokedAt datetime2 NULL,
        CreatedAt datetime2 NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.RefreshTokens') AND name = N'UX_RefreshTokens_TokenHash')
BEGIN
    CREATE UNIQUE INDEX UX_RefreshTokens_TokenHash ON dbo.RefreshTokens(TokenHash);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.RefreshTokens') AND name = N'IX_RefreshTokens_ExpiresAt')
BEGIN
    CREATE INDEX IX_RefreshTokens_ExpiresAt ON dbo.RefreshTokens(ExpiresAt);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Admin')
BEGIN
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Admin', N'System administrator role');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'User')
BEGIN
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'User', N'Default application user role');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'Auditor')
BEGIN
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'Auditor', N'Read-only financial audit role');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = N'FinanceManager')
BEGIN
    INSERT INTO dbo.Roles (RoleName, Description) VALUES (N'FinanceManager', N'Financial operations manager role');
END;
GO

IF OBJECT_ID(N'dbo.UserRoles', N'U') IS NOT NULL
BEGIN
    DECLARE @DefaultUserRoleId int;
    SELECT @DefaultUserRoleId = RoleId FROM dbo.Roles WHERE RoleName = N'User';

    IF @DefaultUserRoleId IS NOT NULL
    BEGIN
        INSERT INTO dbo.UserRoles (UserId, RoleId)
        SELECT u.UserId, @DefaultUserRoleId
        FROM dbo.Users u
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.UserRoles ur
            WHERE ur.UserId = u.UserId
        );
    END;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE CurrencyCode = N'USD')
BEGIN
    INSERT INTO dbo.Currencies (CurrencyCode, Name, Symbol) VALUES (N'USD', N'US Dollar', N'$');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE CurrencyCode = N'EUR')
BEGIN
    INSERT INTO dbo.Currencies (CurrencyCode, Name, Symbol) VALUES (N'EUR', N'Euro', N'EUR');
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Currencies WHERE CurrencyCode = N'THB')
BEGIN
    INSERT INTO dbo.Currencies (CurrencyCode, Name, Symbol) VALUES (N'THB', N'Thai Baht', N'THB');
END;
GO
