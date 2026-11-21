# Report read index remediation

## Purpose

The measured high-load bottlenecks are `GET /reports/account-ledger` and
`GET /reports/trial-balance`. Both read posted journal entries in a date range;
the ledger additionally finds lines for a single account and joins them to their
journal entries.

The schema now defines these SQL Server indexes:

- `IX_JournalEntries_Status_EntryDate_JournalEntryId` on
  `dbo.JournalEntries(Status, EntryDate, JournalEntryId)` for the posted/date
  report filter and entry-to-line join.
- `IX_JournalEntryLines_AccountId_JournalEntryId` on
  `dbo.JournalEntryLines(AccountId, JournalEntryId)` for the account-ledger
  line lookup and join.

They do not change report rows, authorization, report persistence, audit
records, or transaction boundaries.

## Restored benchmark database procedure

The benchmark runner restores the database before each measurement, so restore
alone does not add these indexes. After each restore and before starting the API,
run `Document/sql/20261121_report_read_indexes.sql` against that restored
database. The standalone script creates the indexes when absent and leaves them
unchanged when present, so reapplication is safe.

Before measurement, verify both names are present on the restored database:

```sql
SELECT name
FROM sys.indexes
WHERE object_id IN (OBJECT_ID(N'dbo.JournalEntries'), OBJECT_ID(N'dbo.JournalEntryLines'))
  AND name IN (
      N'IX_JournalEntries_Status_EntryDate_JournalEntryId',
      N'IX_JournalEntryLines_AccountId_JournalEntryId');
```

This remediation deliberately does not include a workload, deployment, or load
test change. A follow-up measurement should compare the same restored dataset
with these indexes applied.
