using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IAccountingPeriodService
    {
        Task<List<AccountingPeriodResponseDto>> GetPeriodsAsync();
        Task<AccountingPeriodResponseDto> CreateAsync(CreateAccountingPeriodRequestDto request, Guid actorUserId, string? ipAddress);
        Task<bool> CloseAsync(int periodId, Guid actorUserId, string? ipAddress);
    }
}
