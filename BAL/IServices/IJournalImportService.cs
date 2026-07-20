using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IJournalImportService
    {
        Task<JournalImportValidationResponseDto> ValidateCsvAsync(
            Stream csv,
            string fileName,
            string idempotencyKey,
            bool atomic,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);

        Task<JournalImportCommitResponseDto> CommitAsync(
            Guid importId,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);
    }
}
