using System.ComponentModel.DataAnnotations;

namespace MODEL.DTOs
{
    public sealed class BankTransactionRequestDto
    {
        [Required]
        public DateTime TransactionDate { get; set; }

        public decimal Amount { get; set; }

        [MaxLength(100)]
        public string? ReferenceNo { get; set; }

        [MaxLength(500)]
        public string? Description { get; set; }
    }

    public sealed class CreateBankReconciliationRequestDto
    {
        [Required]
        public int PeriodId { get; set; }

        [Required]
        public int BankAccountId { get; set; }

        [Required]
        public DateTime DateFrom { get; set; }

        [Required]
        public DateTime DateTo { get; set; }

        [MinLength(1)]
        public List<BankTransactionRequestDto> Transactions { get; set; } = new List<BankTransactionRequestDto>();
    }

    public sealed class ConfirmBankReconciliationMatchRequestDto
    {
        [Required]
        public long BankTransactionId { get; set; }

        [Required]
        public long JournalEntryId { get; set; }

        [Range(1, int.MaxValue)]
        public int ExpectedVersion { get; set; }
    }

    public sealed class FinalizeBankReconciliationRequestDto
    {
        [Required]
        public Guid RequestId { get; set; }

        [Range(1, int.MaxValue)]
        public int ExpectedVersion { get; set; }
    }

    public sealed class BankReconciliationCandidateDto
    {
        public long JournalEntryId { get; set; }
        public int Score { get; set; }
        public bool IsSelected { get; set; }
    }

    public sealed class BankTransactionResultDto
    {
        public long BankTransactionId { get; set; }
        public DateTime TransactionDate { get; set; }
        public decimal Amount { get; set; }
        public string? ReferenceNo { get; set; }
        public string? Description { get; set; }
        public string MatchStatus { get; set; } = string.Empty;
        public long? MatchedJournalEntryId { get; set; }
        public List<BankReconciliationCandidateDto> Candidates { get; set; } = new List<BankReconciliationCandidateDto>();
    }

    public sealed class BankReconciliationResultDto
    {
        public Guid ReconciliationId { get; set; }
        public int PeriodId { get; set; }
        public int BankAccountId { get; set; }
        public DateTime DateFrom { get; set; }
        public DateTime DateTo { get; set; }
        public string Status { get; set; } = string.Empty;
        public int Version { get; set; }
        public DateTime? FinalizedAt { get; set; }
        public bool Replayed { get; set; }
        public List<BankTransactionResultDto> Transactions { get; set; } = new List<BankTransactionResultDto>();
    }

    public sealed class BankReconciliationMatchResultDto
    {
        public Guid ReconciliationId { get; set; }
        public int Version { get; set; }
        public int MatchedCount { get; set; }
        public int AmbiguousCount { get; set; }
        public int UnmatchedCount { get; set; }
        public List<BankTransactionResultDto> Transactions { get; set; } = new List<BankTransactionResultDto>();
    }

    public sealed class BankReconciliationExceptionsDto
    {
        public Guid ReconciliationId { get; set; }
        public int Version { get; set; }
        public List<BankTransactionResultDto> Items { get; set; } = new List<BankTransactionResultDto>();
    }
}
