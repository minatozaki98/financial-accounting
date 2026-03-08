using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IJournalEntryService
    {
        Task<JournalEntryResponseDto> CreateDraftAsync(CreateJournalEntryRequestDto request, Guid actorUserId, string? ipAddress);
        Task<List<long>> BulkCreateDraftAsync(BulkCreateJournalEntriesRequestDto request, Guid actorUserId, string? ipAddress);
        Task<JournalEntryResponseDto?> GetByIdAsync(long journalEntryId);
        Task<PagedResultDto<JournalEntryResponseDto>> GetPagedAsync(JournalEntryQueryRequestDto query);
        Task<bool> PostAsync(long journalEntryId, Guid actorUserId, string? ipAddress);
        Task<long> ReverseAsync(long journalEntryId, Guid actorUserId, string? ipAddress);
        Task<bool> DeleteDraftAsync(long journalEntryId, Guid actorUserId, string? ipAddress);
    }
}

