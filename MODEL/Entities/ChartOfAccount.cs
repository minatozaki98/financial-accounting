using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class ChartOfAccount
    {
        [Key]
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = null!;
        public string AccountName { get; set; } = null!;
        public string AccountType { get; set; } = null!;
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<JournalEntryLine> JournalEntryLines { get; set; } = new List<JournalEntryLine>();
        public ICollection<FinancialReportItem> ReportItems { get; set; } = new List<FinancialReportItem>();
        public ICollection<LedgerBalance> LedgerBalances { get; set; } = new List<LedgerBalance>();
    }
}
