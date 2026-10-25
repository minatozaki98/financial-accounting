#!/usr/bin/env bash
set -euo pipefail
docker exec -i jmeter-research-sql-1 bash -lc 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -d Financial -h -1 -W' <<'SQL'
SET NOCOUNT ON;
SELECT CONCAT('counts ',
              (SELECT COUNT(*) FROM dbo.ChartOfAccounts), ' ',
              (SELECT COUNT(*) FROM dbo.JournalEntries), ' ',
              (SELECT COUNT(*) FROM dbo.JournalEntries WHERE Status=N'Posted'));
SELECT CONCAT('rows ledger_balances ', COUNT(*)) FROM dbo.LedgerBalances;
SELECT CONCAT('rows reports ', COUNT(*)) FROM dbo.Reports;
SELECT CONCAT('rows report_items ', COUNT(*)) FROM dbo.ReportItems;
SELECT CONCAT('rows audit_logs ', COUNT(*)) FROM dbo.AuditLogs;
SELECT CONCAT('index ', OBJECT_NAME(object_id), ' ', name)
FROM sys.indexes
WHERE object_id IN (OBJECT_ID(N'dbo.JournalEntries'), OBJECT_ID(N'dbo.JournalEntryLines'))
  AND name IS NOT NULL
ORDER BY OBJECT_NAME(object_id), name;
GO
SQL
