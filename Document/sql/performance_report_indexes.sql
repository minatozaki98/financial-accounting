SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.JournalEntries', N'U') IS NULL
        THROW 50001, 'dbo.JournalEntries does not exist.', 1;

    IF OBJECT_ID(N'dbo.JournalEntryLines', N'U') IS NULL
        THROW 50002, 'dbo.JournalEntryLines does not exist.', 1;

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

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.JournalEntryLines')
          AND name = N'IX_JournalEntryLines_AccountId_JournalEntryId_JournalEntryLineId'
    )
    BEGIN
        CREATE INDEX IX_JournalEntryLines_AccountId_JournalEntryId_JournalEntryLineId
            ON dbo.JournalEntryLines(AccountId, JournalEntryId, JournalEntryLineId)
            INCLUDE (Debit, Credit);
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
