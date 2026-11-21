SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.JournalEntries')
      AND name = N'IX_JournalEntries_Status_EntryDate_JournalEntryId'
)
BEGIN
    CREATE INDEX IX_JournalEntries_Status_EntryDate_JournalEntryId
        ON dbo.JournalEntries(Status, EntryDate, JournalEntryId);
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
