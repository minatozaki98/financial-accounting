using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IAccountingPeriodService
    {
        Task<List<AccountingPeriodResponseDto>> GetPeriodsAsync();
        Task<AccountingPeriodResponseDto> CreateAsync(CreateAccountingPeriodRequestDto request, Guid actorUserId, string? ipAddress);
        Task<bool> CloseAsync(int periodId, Guid actorUserId, string? ipAddress);
        Task<PeriodClosePreviewDto> PreviewCloseAsync(int periodId, CancellationToken cancellationToken = default);
        Task<PeriodCloseResultDto> CloseAsync(
            int periodId,
            CloseAccountingPeriodRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);
    }
}
