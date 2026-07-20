using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class JournalImportRow
    {
        [Key]
        public long JournalImportRowId { get; set; }
        public Guid ImportId { get; set; }
        public int RowNumber { get; set; }
        public string EntryReference { get; set; } = string.Empty;
        public DateTime? EntryDate { get; set; }
        public string? Description { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public int? AccountId { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public bool IsValid { get; set; }
        public string? Error { get; set; }

        public JournalImportBatch ImportBatch { get; set; } = null!;
        public ChartOfAccount? Account { get; set; }
    }
}
