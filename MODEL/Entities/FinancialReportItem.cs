using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class FinancialReportItem
    {
        [Key]
        public long ReportItemId { get; set; }
        public long ReportId { get; set; }
        public int AccountId { get; set; }
        public decimal DebitTotal { get; set; }
        public decimal CreditTotal { get; set; }
        public decimal Balance { get; set; }

        public FinancialReport Report { get; set; } = null!;
        public ChartOfAccount Account { get; set; } = null!;
    }
}
