using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class BankReconciliation
    {
        [Key]
        public Guid ReconciliationId { get; set; }
        public int PeriodId { get; set; }
        public int BankAccountId { get; set; }
        public DateTime DateFrom { get; set; }
        public DateTime DateTo { get; set; }
        public string Status { get; set; } = "Draft";
        public Guid CreatedByUserId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? FinalizedAt { get; set; }
        public Guid? FinalizeRequestId { get; set; }
        public int Version { get; set; } = 1;

        public AccountingPeriod Period { get; set; } = null!;
        public ChartOfAccount BankAccount { get; set; } = null!;
        public ICollection<BankTransaction> Transactions { get; set; } = new List<BankTransaction>();
    }
}
