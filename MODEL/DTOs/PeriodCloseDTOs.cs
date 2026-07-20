using System.ComponentModel.DataAnnotations;

namespace MODEL.DTOs
{
    public sealed class PeriodClosePreviewDto
    {
        public int PeriodId { get; set; }
        public int Version { get; set; }
        public bool CanClose { get; set; }
        public int DraftEntryCount { get; set; }
        public int PostedEntryCount { get; set; }
        public int UnbalancedPostedEntryCount { get; set; }
        public List<string> Blockers { get; set; } = new List<string>();
    }

    public sealed class CloseAccountingPeriodRequestDto
    {
        [Required]
        public Guid RequestId { get; set; }

        [Range(1, int.MaxValue)]
        public int ExpectedVersion { get; set; }
    }

    public sealed class PeriodCloseResultDto
    {
        public int PeriodId { get; set; }
        public int Version { get; set; }
        public DateTime ClosedAt { get; set; }
        public Guid ClosedByUserId { get; set; }
        public Guid RequestId { get; set; }
        public bool Replayed { get; set; }
    }
}
