using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class AccountingPeriod
    {
        [Key]
        public int PeriodId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsClosed { get; set; }
        public DateTime? ClosedAt { get; set; }
        public Guid? ClosedByUserId { get; set; }
        public Guid? CloseRequestId { get; set; }
        public int Version { get; set; } = 1;

        public Users? ClosedByUser { get; set; }
        public ICollection<FinancialReport> Reports { get; set; } = new List<FinancialReport>();
        public ICollection<LedgerBalance> LedgerBalances { get; set; } = new List<LedgerBalance>();
        public ICollection<BankReconciliation> BankReconciliations { get; set; } = new List<BankReconciliation>();
    }
}

