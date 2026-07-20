using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class BankTransaction
    {
        [Key]
        public long BankTransactionId { get; set; }
        public Guid ReconciliationId { get; set; }
        public DateTime TransactionDate { get; set; }
        public decimal Amount { get; set; }
        public string? ReferenceNo { get; set; }
        public string? Description { get; set; }
        public string MatchStatus { get; set; } = "Unmatched";
        public long? MatchedJournalEntryId { get; set; }

        public BankReconciliation Reconciliation { get; set; } = null!;
        public JournalEntry? MatchedJournalEntry { get; set; }
        public ICollection<BankReconciliationCandidate> Candidates { get; set; } = new List<BankReconciliationCandidate>();
    }
}
