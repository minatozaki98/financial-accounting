using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class LedgerBalance
    {
        [Key]
        public long LedgerBalanceId { get; set; }
        public int AccountId { get; set; }
        public int PeriodId { get; set; }
        public decimal DebitTotal { get; set; }
        public decimal CreditTotal { get; set; }
        public decimal Balance { get; set; }
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ChartOfAccount Account { get; set; } = null!;
        public AccountingPeriod Period { get; set; } = null!;
    }
}
