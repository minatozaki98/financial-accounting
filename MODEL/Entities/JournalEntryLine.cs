using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class JournalEntryLine
    {
        [Key]
        public long JournalEntryLineId { get; set; }
        public long JournalEntryId { get; set; }
        public int AccountId { get; set; }
        public string? LineDescription { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }

        public JournalEntry JournalEntry { get; set; } = null!;
        public ChartOfAccount Account { get; set; } = null!;
    }
}
