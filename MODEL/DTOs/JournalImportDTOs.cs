namespace MODEL.DTOs
{
    public sealed class JournalImportErrorDto
    {
        public int RowNumber { get; set; }
        public string Error { get; set; } = string.Empty;
    }

    public sealed class JournalImportValidationResponseDto
    {
        public Guid ImportId { get; set; }
        public string Status { get; set; } = string.Empty;
        public bool Atomic { get; set; }
        public int TotalRows { get; set; }
        public int ValidRows { get; set; }
        public int InvalidRows { get; set; }
        public bool Replayed { get; set; }
        public List<JournalImportErrorDto> Errors { get; set; } = new List<JournalImportErrorDto>();
    }

    public sealed class JournalImportCommitResponseDto
    {
        public Guid ImportId { get; set; }
        public string Status { get; set; } = string.Empty;
        public List<long> CreatedEntryIds { get; set; } = new List<long>();
        public bool Replayed { get; set; }
    }
}
