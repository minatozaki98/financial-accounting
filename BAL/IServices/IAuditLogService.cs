using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IAuditLogService
    {
        Task WriteAsync(Guid? userId, string action, string? entityName, string? entityId, string? ipAddress, object? details = null);
        Task<PagedResultDto<AuditLogResponseDto>> GetPagedAsync(
            DateTime? from,
            DateTime? to,
            Guid? userId,
            string? action,
            int page,
            int pageSize);
    }
}
