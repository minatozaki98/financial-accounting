using BAL.IServices;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.Entities;

namespace BAL.Services
{
    internal sealed class LedgerBalanceService : ILedgerBalanceService
    {
        private const string PostedStatus = "Posted";
        private readonly DataContext _context;

        public LedgerBalanceService(DataContext context)
        {
            _context = context;
        }

        public async Task RefreshForPeriodAsync(int periodId, CancellationToken cancellationToken = default)
        {
            var period = await _context.AccountingPeriods
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.PeriodId == periodId, cancellationToken);
            if (period == null)
            {
                return;
            }

            var aggregates = await (
                    from entry in _context.JournalEntries
                    join line in _context.JournalEntryLines on entry.JournalEntryId equals line.JournalEntryId
                    join account in _context.ChartOfAccounts on line.AccountId equals account.AccountId
                    where entry.Status == PostedStatus &&
                          entry.EntryDate >= period.StartDate &&
                          entry.EntryDate <= period.EndDate
                    group new { line, account } by new { line.AccountId, account.AccountType }
                    into grouped
                    select new
                    {
                        grouped.Key.AccountId,
                        grouped.Key.AccountType,
                        DebitTotal = grouped.Sum(item => (double)item.line.Debit),
                        CreditTotal = grouped.Sum(item => (double)item.line.Credit)
                    })
                .ToListAsync(cancellationToken);

            var existing = await _context.LedgerBalances
                .Where(item => item.PeriodId == periodId)
                .ToListAsync(cancellationToken);
            var existingMap = existing.ToDictionary(item => item.AccountId);
            var aggregateIds = aggregates.Select(item => item.AccountId).ToHashSet();

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

                row.DebitTotal = decimal.Round(Convert.ToDecimal(aggregate.DebitTotal), 2);
                row.CreditTotal = decimal.Round(Convert.ToDecimal(aggregate.CreditTotal), 2);
                row.Balance = NormalizeBalance(aggregate.AccountType, row.DebitTotal, row.CreditTotal);
                row.UpdatedAt = DateTime.UtcNow;
            }

            foreach (var stale in existing.Where(item => !aggregateIds.Contains(item.AccountId)))
            {
                _context.LedgerBalances.Remove(stale);
            }

            await _context.SaveChangesAsync(cancellationToken);
        }

        private static decimal NormalizeBalance(string accountType, decimal debitTotal, decimal creditTotal)
        {
            return accountType.Equals("Liability", StringComparison.OrdinalIgnoreCase) ||
                   accountType.Equals("Equity", StringComparison.OrdinalIgnoreCase) ||
                   accountType.Equals("Revenue", StringComparison.OrdinalIgnoreCase)
                ? creditTotal - debitTotal
                : debitTotal - creditTotal;
        }
    }
}
