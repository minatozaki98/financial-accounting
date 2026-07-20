using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class BankReconciliationCandidate
    {
        [Key]
        public long BankReconciliationCandidateId { get; set; }
        public long BankTransactionId { get; set; }
        public long JournalEntryId { get; set; }
        public int Score { get; set; }
        public bool IsSelected { get; set; }

        public BankTransaction BankTransaction { get; set; } = null!;
        public JournalEntry JournalEntry { get; set; } = null!;
    }
}
