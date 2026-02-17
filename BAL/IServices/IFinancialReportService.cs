using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IFinancialReportService
    {
        Task<TrialBalanceResponseDto> GetTrialBalanceAsync(int periodId, Guid actorUserId, string? ipAddress);
        Task<ProfitLossResponseDto> GetProfitLossAsync(int periodId, Guid actorUserId, string? ipAddress);
        Task<BalanceSheetResponseDto> GetBalanceSheetAsync(int periodId, Guid actorUserId, string? ipAddress);
        Task<AccountLedgerResponseDto> GetAccountLedgerAsync(int accountId, int periodId, Guid actorUserId, string? ipAddress);
    }
}
