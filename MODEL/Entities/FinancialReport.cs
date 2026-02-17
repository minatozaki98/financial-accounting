using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class FinancialReport
    {
        [Key]
        public long ReportId { get; set; }
        public string ReportType { get; set; } = null!;
        public int PeriodId { get; set; }
        public Guid GeneratedByUserId { get; set; }
        public DateTime GeneratedAt { get; set; } = DateTime.UtcNow;

        public AccountingPeriod Period { get; set; } = null!;
        public Users GeneratedByUser { get; set; } = null!;
        public ICollection<FinancialReportItem> ReportItems { get; set; } = new List<FinancialReportItem>();
    }
}
