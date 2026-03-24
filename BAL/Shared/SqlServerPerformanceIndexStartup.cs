using Microsoft.EntityFrameworkCore;
using MODEL;

namespace BAL.Shared
{
    public sealed class SqlServerPerformanceIndexStartup
    {
        private readonly DataContext _context;

        public SqlServerPerformanceIndexStartup(DataContext context)
        {
            _context = context;
        }

        public async Task EnsureAsync(CancellationToken cancellationToken = default)
        {
            if (!_context.Database.IsSqlServer())
            {
                return;
            }

            const string sql = """
                IF OBJECT_ID(N'[dbo].[JournalEntries]', N'U') IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1
                       FROM sys.indexes
                       WHERE name = N'IX_JournalEntries_Status_EntryDate_JournalEntryId'
                         AND object_id = OBJECT_ID(N'[dbo].[JournalEntries]')
                   )
                BEGIN
                    CREATE NONCLUSTERED INDEX [IX_JournalEntries_Status_EntryDate_JournalEntryId]
                    ON [dbo].[JournalEntries] ([Status], [EntryDate], [JournalEntryId])
                    INCLUDE ([ReferenceNo], [Description]);
                END;

                IF OBJECT_ID(N'[dbo].[JournalEntryLines]', N'U') IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1
                       FROM sys.indexes
                       WHERE name = N'IX_JournalEntryLines_AccountId_JournalEntryId_JournalEntryLineId'
                         AND object_id = OBJECT_ID(N'[dbo].[JournalEntryLines]')
                   )
                BEGIN
                    CREATE NONCLUSTERED INDEX [IX_JournalEntryLines_AccountId_JournalEntryId_JournalEntryLineId]
                    ON [dbo].[JournalEntryLines] ([AccountId], [JournalEntryId], [JournalEntryLineId])
                    INCLUDE ([Debit], [Credit], [LineDescription]);
                END;
                """;

            await _context.Database.ExecuteSqlRawAsync(sql, cancellationToken);
        }
    }
}
