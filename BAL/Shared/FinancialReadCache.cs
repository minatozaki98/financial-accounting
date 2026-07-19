using Microsoft.Extensions.Caching.Memory;
using System.Threading;

namespace BAL.Shared
{
    internal sealed class FinancialReadCache
    {
        private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

        private readonly IMemoryCache _cache;
        private int _accountVersion;
        private int _periodVersion;
        private int _reportVersion;
        private int _ledgerVersion;

        public FinancialReadCache(IMemoryCache cache)
        {
            _cache = cache;
        }

        public Task<T> GetOrCreateAccountsAsync<T>(string key, Func<Task<T>> factory)
        {
            return GetOrCreateAsync($"accounts:v{_accountVersion}:{key}", factory);
        }

        public Task<T> GetOrCreatePeriodsAsync<T>(Func<Task<T>> factory)
        {
            return GetOrCreateAsync($"periods:v{_periodVersion}", factory);
        }

        public Task<T> GetOrCreateReportAsync<T>(int periodId, string key, Func<Task<T>> factory)
        {
            return GetOrCreateAsync($"report:v{_reportVersion}:p{periodId}:{key}", factory);
        }

        public Task<T> GetOrCreateLedgerAsync<T>(int accountId, int periodId, Func<Task<T>> factory)
        {
            return GetOrCreateAsync($"ledger:v{_ledgerVersion}:p{periodId}:a{accountId}", factory);
        }

        public void InvalidateAccounts()
        {
            Interlocked.Increment(ref _accountVersion);
            Interlocked.Increment(ref _reportVersion);
            Interlocked.Increment(ref _ledgerVersion);
        }

        public void InvalidatePeriods()
        {
            Interlocked.Increment(ref _periodVersion);
            Interlocked.Increment(ref _reportVersion);
            Interlocked.Increment(ref _ledgerVersion);
        }

        public void InvalidatePostedEntries()
        {
            Interlocked.Increment(ref _reportVersion);
            Interlocked.Increment(ref _ledgerVersion);
        }

        private async Task<T> GetOrCreateAsync<T>(string key, Func<Task<T>> factory)
        {
            if (_cache.TryGetValue(key, out T? cached) && cached is not null)
            {
                return cached;
            }

            var created = await factory();
            _cache.Set(key, created, CacheDuration);
            return created;
        }
    }
}
