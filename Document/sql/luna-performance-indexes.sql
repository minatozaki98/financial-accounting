-- Idempotent indexes for report and account-ledger read paths.
-- Apply this file to the restored disposable benchmark database before each run.

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.JournalEntries')
      AND name = N'IX_JournalEntries_Status_EntryDate'
)
BEGIN
    CREATE INDEX IX_JournalEntries_Status_EntryDate
        ON dbo.JournalEntries(Status, EntryDate);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.JournalEntryLines')
      AND name = N'IX_JournalEntryLines_AccountId_JournalEntryId'
)
BEGIN
    CREATE INDEX IX_JournalEntryLines_AccountId_JournalEntryId
        ON dbo.JournalEntryLines(AccountId, JournalEntryId);
END;
GO
