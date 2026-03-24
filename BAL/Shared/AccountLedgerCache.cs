using System.Collections.Concurrent;
using System.Globalization;
using BAL.IServices;
using MODEL.DTOs;

namespace BAL.Shared
{
    public sealed class AccountLedgerCache : IAccountLedgerCache
    {
        private readonly ConcurrentDictionary<string, Lazy<Task<AccountLedgerSnapshot>>> _entries = new();
        private readonly ConcurrentDictionary<string, Lazy<Task<AccountLedgerPayload>>> _payloads = new();

        public async Task<AccountLedgerSnapshot> GetOrCreateAsync(
            int accountId,
            int periodId,
            string accountType,
            DateTime startDate,
            DateTime endDate,
            Func<Task<AccountLedgerSnapshot>> factory)
        {
            var key = BuildKey(accountId, periodId, accountType, startDate, endDate);
            var lazy = _entries.GetOrAdd(
                key,
                _ => new Lazy<Task<AccountLedgerSnapshot>>(factory, LazyThreadSafetyMode.ExecutionAndPublication));

            try
            {
                return await lazy.Value;
            }
            catch
            {
                _entries.TryRemove(new KeyValuePair<string, Lazy<Task<AccountLedgerSnapshot>>>(key, lazy));
                throw;
            }
        }

        public void Invalidate(int accountId, int periodId)
        {
            var prefix = BuildPrefix(accountId, periodId);
            foreach (var entry in _entries)
            {
                if (!entry.Key.StartsWith(prefix, StringComparison.Ordinal))
                {
                    continue;
                }

                _entries.TryRemove(entry);
            }

            foreach (var payload in _payloads)
            {
                if (!payload.Key.StartsWith(prefix, StringComparison.Ordinal))
                {
                    continue;
                }

                _payloads.TryRemove(payload);
            }
        }

        public void Invalidate(IEnumerable<int> accountIds, int periodId)
        {
            foreach (var accountId in accountIds.Distinct())
            {
                Invalidate(accountId, periodId);
            }
        }

        public async Task<AccountLedgerPayload> GetOrCreatePayloadAsync(
            int accountId,
            int periodId,
            string accountType,
            DateTime startDate,
            DateTime endDate,
            Func<Task<AccountLedgerPayload>> factory)
        {
            var key = BuildKey(accountId, periodId, accountType, startDate, endDate);
            var lazy = _payloads.GetOrAdd(
                key,
                _ => new Lazy<Task<AccountLedgerPayload>>(factory, LazyThreadSafetyMode.ExecutionAndPublication));

            try
            {
                return await lazy.Value;
            }
            catch
            {
                _payloads.TryRemove(new KeyValuePair<string, Lazy<Task<AccountLedgerPayload>>>(key, lazy));
                throw;
            }
        }

        private static string BuildKey(int accountId, int periodId, string accountType, DateTime startDate, DateTime endDate)
        {
            return string.Create(
                CultureInfo.InvariantCulture,
                $"{BuildPrefix(accountId, periodId)}{accountType}:{startDate:yyyyMMdd}:{endDate:yyyyMMdd}");
        }

        private static string BuildPrefix(int accountId, int periodId)
        {
            return string.Create(CultureInfo.InvariantCulture, $"{accountId}:{periodId}:");
        }
    }

    public sealed record AccountLedgerSnapshot(
        decimal OpeningBalance,
        decimal ClosingBalance,
        decimal DebitTotal,
        decimal CreditTotal,
        List<AccountLedgerLineDto> Lines);

    public sealed record AccountLedgerPayload(
        AccountLedgerResponseDto Response,
        decimal DebitTotal,
        decimal CreditTotal,
        byte[] JsonUtf8);
}
