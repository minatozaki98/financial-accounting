using BAL.Shared;

namespace BAL.IServices
{
    public interface IAccountLedgerCache
    {
        Task<AccountLedgerSnapshot> GetOrCreateAsync(
            int accountId,
            int periodId,
            string accountType,
            DateTime startDate,
            DateTime endDate,
            Func<Task<AccountLedgerSnapshot>> factory);

        Task<AccountLedgerPayload> GetOrCreatePayloadAsync(
            int accountId,
            int periodId,
            string accountType,
            DateTime startDate,
            DateTime endDate,
            Func<Task<AccountLedgerPayload>> factory);

        void Invalidate(int accountId, int periodId);
        void Invalidate(IEnumerable<int> accountIds, int periodId);
    }
}
