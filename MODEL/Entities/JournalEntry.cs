using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class JournalEntry
    {
        [Key]
        public long JournalEntryId { get; set; }
        public DateTime EntryDate { get; set; }
        public string? Description { get; set; }
        public string? ReferenceNo { get; set; }
        public string Status { get; set; } = "Draft";
        public Guid CreatedByUserId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? PostedAt { get; set; }
        public DateTime? ReversedAt { get; set; }

        public Users CreatedByUser { get; set; } = null!;
        public ICollection<JournalEntryLine> Lines { get; set; } = new List<JournalEntryLine>();
    }
}
