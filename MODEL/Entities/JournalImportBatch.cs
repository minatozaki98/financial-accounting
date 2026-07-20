using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class JournalImportBatch
    {
        [Key]
        public Guid ImportId { get; set; }
        public Guid CreatedByUserId { get; set; }
        public string IdempotencyKey { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public bool Atomic { get; set; }
        public string Status { get; set; } = "Validated";
        public int TotalRows { get; set; }
        public int ValidRows { get; set; }
        public int InvalidRows { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? CommittedAt { get; set; }

        public ICollection<JournalImportRow> Rows { get; set; } = new List<JournalImportRow>();
        public ICollection<JournalEntry> CreatedEntries { get; set; } = new List<JournalEntry>();
    }
}
