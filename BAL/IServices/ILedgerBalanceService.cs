namespace BAL.IServices
{
    public interface ILedgerBalanceService
    {
        Task RefreshForPeriodAsync(int periodId, CancellationToken cancellationToken = default);
    }
}
