using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IFinancialAuthService
    {
        Task<FinancialTokenResponseDto?> LoginAsync(FinancialLoginRequestDto request, string? ipAddress);
        Task<CurrentUserResponseDto?> GetCurrentUserAsync(Guid userId);
        Task<CreatedUserResponseDto> CreateUserAsync(CreateUserRequestDto request, Guid actorUserId, string? ipAddress);
    }
}
