using BAL.IServices;
using BAL.Shared;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BAL.Services
{
    internal class FinancialReportService : IFinancialReportService
    {
        private static readonly SemaphoreSlim LedgerBalanceRefreshLock = new(1, 1);
        private static readonly JsonSerializerOptions AccountLedgerJsonOptions = new()
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };
        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;
        private readonly IAccountLedgerCache _accountLedgerCache;

        public FinancialReportService(DataContext context, IAuditLogService auditLogService, IAccountLedgerCache accountLedgerCache)
        {
            _context = context;
            _auditLogService = auditLogService;
            _accountLedgerCache = accountLedgerCache;
        }

        public async Task<TrialBalanceResponseDto> GetTrialBalanceAsync(int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await GetPeriodOrThrowAsync(periodId);
            var aggregates = await GetPeriodAggregatesAsync(periodId, period.StartDate, period.EndDate);
            var items = aggregates.Select(MapToReportItem).ToList();

            await PersistReportAsync("TrialBalance", periodId, actorUserId, ipAddress, items);

            return new TrialBalanceResponseDto
            {
                PeriodId = periodId,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                TotalDebit = items.Sum(x => x.DebitTotal),
                TotalCredit = items.Sum(x => x.CreditTotal),
                Items = items
            };
        }

        public async Task<ProfitLossResponseDto> GetProfitLossAsync(int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await GetPeriodOrThrowAsync(periodId);
            var aggregates = await GetPeriodAggregatesAsync(periodId, period.StartDate, period.EndDate);

            var items = aggregates
                .Where(x =>
                    x.AccountType.Equals("Revenue", StringComparison.OrdinalIgnoreCase) ||
                    x.AccountType.Equals("Expense", StringComparison.OrdinalIgnoreCase))
                .Select(MapToReportItem)
                .ToList();

            var totalRevenue = items
                .Where(x => x.AccountType.Equals("Revenue", StringComparison.OrdinalIgnoreCase))
                .Sum(x => x.Balance);
            var totalExpense = items
                .Where(x => x.AccountType.Equals("Expense", StringComparison.OrdinalIgnoreCase))
                .Sum(x => x.Balance);

            await PersistReportAsync("ProfitLoss", periodId, actorUserId, ipAddress, items);

            return new ProfitLossResponseDto
            {
                PeriodId = periodId,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                TotalRevenue = totalRevenue,
                TotalExpense = totalExpense,
                NetProfit = totalRevenue - totalExpense,
                Items = items
            };
        }

        public async Task<BalanceSheetResponseDto> GetBalanceSheetAsync(int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await GetPeriodOrThrowAsync(periodId);
            var aggregates = await GetPeriodAggregatesAsync(periodId, period.StartDate, period.EndDate);

            var items = aggregates
                .Where(x =>
                    x.AccountType.Equals("Asset", StringComparison.OrdinalIgnoreCase) ||
                    x.AccountType.Equals("Liability", StringComparison.OrdinalIgnoreCase) ||
                    x.AccountType.Equals("Equity", StringComparison.OrdinalIgnoreCase))
                .Select(MapToReportItem)
                .ToList();

            await PersistReportAsync("BalanceSheet", periodId, actorUserId, ipAddress, items);

            return new BalanceSheetResponseDto
            {
                PeriodId = periodId,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                TotalAssets = items.Where(x => x.AccountType.Equals("Asset", StringComparison.OrdinalIgnoreCase)).Sum(x => x.Balance),
                TotalLiabilities = items.Where(x => x.AccountType.Equals("Liability", StringComparison.OrdinalIgnoreCase)).Sum(x => x.Balance),
                TotalEquity = items.Where(x => x.AccountType.Equals("Equity", StringComparison.OrdinalIgnoreCase)).Sum(x => x.Balance),
                Items = items
            };
        }

        public async Task<AccountLedgerResponseDto> GetAccountLedgerAsync(int accountId, int periodId, Guid actorUserId, string? ipAddress)
        {
            var payload = await GetAccountLedgerPayloadAsync(accountId, periodId, actorUserId, ipAddress);
            return payload.Response;
        }

        public async Task<AccountLedgerPayload> GetAccountLedgerPayloadAsync(int accountId, int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await GetPeriodOrThrowAsync(periodId);
            var account = await _context.ChartOfAccounts.AsNoTracking().FirstOrDefaultAsync(x => x.AccountId == accountId);
            if (account == null)
            {
                throw new InvalidOperationException("Account was not found.");
            }

            var payload = await _accountLedgerCache.GetOrCreatePayloadAsync(
                accountId,
                periodId,
                account.AccountType,
                period.StartDate,
                period.EndDate,
                () => BuildAccountLedgerPayloadAsync(accountId, period, account));

            await PersistReportAsync(
                "Ledger",
                periodId,
                actorUserId,
                ipAddress,
                new List<ReportItemDto>
                {
                    new ReportItemDto
                    {
                        AccountId = account.AccountId,
                        AccountCode = account.AccountCode,
                        AccountName = account.AccountName,
                        AccountType = account.AccountType,
                        DebitTotal = payload.DebitTotal,
                        CreditTotal = payload.CreditTotal,
                        Balance = payload.Response.ClosingBalance
                    }
                });

            return payload;
        }

        private async Task<AccountLedgerPayload> BuildAccountLedgerPayloadAsync(int accountId, AccountingPeriod period, ChartOfAccount account)
        {
            var openingSums = await (
                    from entry in _context.JournalEntries
                    join line in _context.JournalEntryLines on entry.JournalEntryId equals line.JournalEntryId
                    where entry.Status == "Posted" &&
                          line.AccountId == accountId &&
                          entry.EntryDate < period.StartDate
                    group line by 1
                into grouped
                    select new
                    {
                        DebitTotal = grouped.Sum(x => (double)x.Debit),
                        CreditTotal = grouped.Sum(x => (double)x.Credit)
                    })
                .FirstOrDefaultAsync();

            var openingBalance = NormalizeBalance(
                account.AccountType,
                decimal.Round(Convert.ToDecimal(openingSums?.DebitTotal ?? 0d), 2),
                decimal.Round(Convert.ToDecimal(openingSums?.CreditTotal ?? 0d), 2));

            var lines = await (
                    from entry in _context.JournalEntries.AsNoTracking()
                    join line in _context.JournalEntryLines.AsNoTracking() on entry.JournalEntryId equals line.JournalEntryId
                    where entry.Status == "Posted" &&
                          line.AccountId == accountId &&
                          entry.EntryDate >= period.StartDate &&
                          entry.EntryDate <= period.EndDate
                    orderby entry.EntryDate, entry.JournalEntryId, line.JournalEntryLineId
                    select new
                    {
                        entry.EntryDate,
                        entry.JournalEntryId,
                        entry.ReferenceNo,
                        EntryDescription = entry.Description,
                        line.LineDescription,
                        line.Debit,
                        line.Credit
                    })
                .ToListAsync();

            var runningBalance = openingBalance;
            var ledgerLines = new List<AccountLedgerLineDto>(lines.Count);
            foreach (var line in lines)
            {
                runningBalance += NormalizeBalance(account.AccountType, line.Debit, line.Credit);
                ledgerLines.Add(new AccountLedgerLineDto
                {
                    EntryDate = line.EntryDate,
                    JournalEntryId = line.JournalEntryId,
                    ReferenceNo = line.ReferenceNo,
                    EntryDescription = line.EntryDescription,
                    LineDescription = line.LineDescription,
                    Debit = line.Debit,
                    Credit = line.Credit,
                    RunningBalance = runningBalance
                });
            }

            var debitTotal = ledgerLines.Sum(x => x.Debit);
            var creditTotal = ledgerLines.Sum(x => x.Credit);
            var response = new AccountLedgerResponseDto
            {
                PeriodId = period.PeriodId,
                AccountId = account.AccountId,
                AccountCode = account.AccountCode,
                AccountName = account.AccountName,
                AccountType = account.AccountType,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                OpeningBalance = openingBalance,
                ClosingBalance = runningBalance,
                Lines = ledgerLines
            };

            return new AccountLedgerPayload(
                Response: response,
                DebitTotal: debitTotal,
                CreditTotal: creditTotal,
                JsonUtf8: JsonSerializer.SerializeToUtf8Bytes(response, AccountLedgerJsonOptions));
        }

        private async Task<AccountingPeriod> GetPeriodOrThrowAsync(int periodId)
        {
            var period = await _context.AccountingPeriods.AsNoTracking().FirstOrDefaultAsync(x => x.PeriodId == periodId);
            if (period == null)
            {
                throw new InvalidOperationException($"Accounting period '{periodId}' was not found.");
            }

            return period;
        }

        private async Task<List<AccountAggregate>> GetPeriodAggregatesAsync(int periodId, DateTime startDate, DateTime endDate)
        {
            var ledgerBalances = await GetLedgerBalanceAggregatesAsync(periodId);
            if (ledgerBalances.Count > 0)
            {
                return ledgerBalances;
            }

            await LedgerBalanceRefreshLock.WaitAsync();
            try
            {
                ledgerBalances = await GetLedgerBalanceAggregatesAsync(periodId);
                if (ledgerBalances.Count > 0)
                {
                    return ledgerBalances;
                }

                var rawAggregates = await GetRawPeriodAggregatesAsync(startDate, endDate);
                await UpsertLedgerBalancesAsync(periodId, rawAggregates);
                return rawAggregates;
            }
            finally
            {
                LedgerBalanceRefreshLock.Release();
            }
        }

        private async Task<List<AccountAggregate>> GetLedgerBalanceAggregatesAsync(int periodId)
        {
            return await (
                    from balance in _context.LedgerBalances.AsNoTracking()
                    join account in _context.ChartOfAccounts.AsNoTracking() on balance.AccountId equals account.AccountId
                    where balance.PeriodId == periodId
                    orderby account.AccountCode
                    select new AccountAggregate
                    {
                        AccountId = account.AccountId,
                        AccountCode = account.AccountCode,
                        AccountName = account.AccountName,
                        AccountType = account.AccountType,
                        DebitTotal = balance.DebitTotal,
                        CreditTotal = balance.CreditTotal
                    })
                .ToListAsync();
        }

        private async Task<List<AccountAggregate>> GetRawPeriodAggregatesAsync(DateTime startDate, DateTime endDate)
        {
            var rows = await (
                    from entry in _context.JournalEntries.AsNoTracking()
                    join line in _context.JournalEntryLines.AsNoTracking() on entry.JournalEntryId equals line.JournalEntryId
                    join account in _context.ChartOfAccounts.AsNoTracking() on line.AccountId equals account.AccountId
                    where entry.Status == "Posted" &&
                          entry.EntryDate >= startDate &&
                          entry.EntryDate <= endDate
                    group new { line, account } by new
                    {
                        account.AccountId,
                        account.AccountCode,
                        account.AccountName,
                        account.AccountType
                    }
                into grouped
                    select new
                    {
                        AccountId = grouped.Key.AccountId,
                        AccountCode = grouped.Key.AccountCode,
                        AccountName = grouped.Key.AccountName,
                        AccountType = grouped.Key.AccountType,
                        DebitTotal = grouped.Sum(x => (double)x.line.Debit),
                        CreditTotal = grouped.Sum(x => (double)x.line.Credit)
                    })
                .OrderBy(x => x.AccountCode)
                .ToListAsync();

            return rows
                .Select(x => new AccountAggregate
                {
                    AccountId = x.AccountId,
                    AccountCode = x.AccountCode,
                    AccountName = x.AccountName,
                    AccountType = x.AccountType,
                    DebitTotal = decimal.Round(Convert.ToDecimal(x.DebitTotal), 2),
                    CreditTotal = decimal.Round(Convert.ToDecimal(x.CreditTotal), 2)
                })
                .ToList();
        }

        private async Task UpsertLedgerBalancesAsync(int periodId, List<AccountAggregate> aggregates)
        {
            var existing = await _context.LedgerBalances
                .Where(x => x.PeriodId == periodId)
                .ToListAsync();

            var existingMap = existing.ToDictionary(x => x.AccountId, x => x);
            var aggregateIds = aggregates.Select(x => x.AccountId).ToHashSet();

            foreach (var aggregate in aggregates)
            {
                if (!existingMap.TryGetValue(aggregate.AccountId, out var row))
                {
                    row = new LedgerBalance
                    {
                        PeriodId = periodId,
                        AccountId = aggregate.AccountId
                    };
                    _context.LedgerBalances.Add(row);
                }

                row.DebitTotal = aggregate.DebitTotal;
                row.CreditTotal = aggregate.CreditTotal;
                row.Balance = NormalizeBalance(aggregate.AccountType, aggregate.DebitTotal, aggregate.CreditTotal);
                row.UpdatedAt = DateTime.UtcNow;
            }

            foreach (var stale in existing.Where(x => !aggregateIds.Contains(x.AccountId)))
            {
                _context.LedgerBalances.Remove(stale);
            }

            await _context.SaveChangesAsync();
        }

        private async Task PersistReportAsync(
            string reportType,
            int periodId,
            Guid actorUserId,
            string? ipAddress,
            List<ReportItemDto> items)
        {
            await _auditLogService.WriteAsync(
                actorUserId,
                "GENERATE_REPORT",
                "Reports",
                $"{reportType}:{periodId}",
                ipAddress,
                new { reportType, periodId, items = items.Count });
        }

        private static ReportItemDto MapToReportItem(AccountAggregate aggregate)
        {
            return new ReportItemDto
            {
                AccountId = aggregate.AccountId,
                AccountCode = aggregate.AccountCode,
                AccountName = aggregate.AccountName,
                AccountType = aggregate.AccountType,
                DebitTotal = aggregate.DebitTotal,
                CreditTotal = aggregate.CreditTotal,
                Balance = NormalizeBalance(aggregate.AccountType, aggregate.DebitTotal, aggregate.CreditTotal)
            };
        }

        private static decimal NormalizeBalance(string accountType, decimal debitTotal, decimal creditTotal)
        {
            if (accountType.Equals("Liability", StringComparison.OrdinalIgnoreCase) ||
                accountType.Equals("Equity", StringComparison.OrdinalIgnoreCase) ||
                accountType.Equals("Revenue", StringComparison.OrdinalIgnoreCase))
            {
                return creditTotal - debitTotal;
            }

            return debitTotal - creditTotal;
        }

        private class AccountAggregate
        {
            public int AccountId { get; set; }
            public string AccountCode { get; set; } = string.Empty;
            public string AccountName { get; set; } = string.Empty;
            public string AccountType { get; set; } = string.Empty;
            public decimal DebitTotal { get; set; }
            public decimal CreditTotal { get; set; }
        }
    }
}
