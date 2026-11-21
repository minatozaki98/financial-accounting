# Luna performance remediation

The report and account-ledger queries filter posted journal entries by date and
join journal-entry lines by account. The model now declares composite indexes
for those access paths, and the read queries avoid retaining entity graphs in
the request context. Journal-entry list reads also use split queries to avoid
duplicating entry columns for every line.

## Restored-database application

The benchmark runner restores its disposable SQL database before each
measurement. Applying only the EF model does not add indexes to an already
restored database, so the runner must apply the standalone
`Document/sql/luna-performance-indexes.sql` file to that disposable copy
before starting the API. It adds the two indexes with `IF NOT EXISTS` guards,
so applying it after every restore (including twice during a validation pass)
is safe and does not alter data. The full schema script contains the same
guarded index definitions for fresh schema setup.

No JMeter, load, deployment, or workload configuration was changed by this
remediation.
