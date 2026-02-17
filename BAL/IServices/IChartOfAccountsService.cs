using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IChartOfAccountsService
    {
        Task<List<AccountResponseDto>> GetAccountsAsync(string? type, bool? isActive, string? search);
        Task<AccountResponseDto?> GetByIdAsync(int accountId);
        Task<AccountBalanceResponseDto?> GetBalanceAsync(int accountId);
        Task<AccountResponseDto> CreateAsync(CreateAccountRequestDto request, Guid actorUserId, string? ipAddress);
        Task<bool> UpdateAsync(int accountId, UpdateAccountRequestDto request, Guid actorUserId, string? ipAddress);
    }
}
