using System.ComponentModel.DataAnnotations;

namespace MODEL.DTOs
{
    public class FinancialLoginRequestDto
    {
        [Required]
        [MaxLength(100)]
        public string Username { get; set; } = string.Empty;

        [Required]
        public string Password { get; set; } = string.Empty;
    }

    public class FinancialTokenResponseDto
    {
        public string AccessToken { get; set; } = string.Empty;
        public DateTime AccessTokenExpiresAtUtc { get; set; }
        public List<string> Roles { get; set; } = new List<string>();
    }

    public class CurrentUserResponseDto
    {
        public Guid UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public List<string> Roles { get; set; } = new List<string>();
    }

    public class CreateUserRequestDto
    {
        [Required]
        [MaxLength(100)]
        public string Username { get; set; } = string.Empty;

        [Required]
        [EmailAddress]
        [MaxLength(200)]
        public string Email { get; set; } = string.Empty;

        [Required]
        [MinLength(8)]
        public string Password { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Role { get; set; } = string.Empty;
    }

    public class CreatedUserResponseDto
    {
        public Guid UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public bool IsActive { get; set; }
    }

    public class CreateAccountRequestDto
    {
        [Required]
        [MaxLength(20)]
        public string AccountCode { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string AccountName { get; set; } = string.Empty;

        [Required]
        [MaxLength(20)]
        public string AccountType { get; set; } = string.Empty;

        public bool IsActive { get; set; } = true;
    }

    public class UpdateAccountRequestDto
    {
        [Required]
        [MaxLength(200)]
        public string AccountName { get; set; } = string.Empty;

        [Required]
        [MaxLength(20)]
        public string AccountType { get; set; } = string.Empty;

        public bool IsActive { get; set; } = true;
    }

    public class AccountResponseDto
    {
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string AccountType { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class AccountBalanceResponseDto
    {
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string AccountType { get; set; } = string.Empty;
        public decimal DebitTotal { get; set; }
        public decimal CreditTotal { get; set; }
        public decimal Balance { get; set; }
    }

    public class JournalEntryLineRequestDto
    {
        [Required]
        public int AccountId { get; set; }

        [MaxLength(500)]
        public string? LineDescription { get; set; }

        [Range(0, 999999999999.99)]
        public decimal Debit { get; set; }

        [Range(0, 999999999999.99)]
        public decimal Credit { get; set; }
    }

    public class CreateJournalEntryRequestDto
    {
        [Required]
        public DateTime EntryDate { get; set; }

        [MaxLength(500)]
        public string? Description { get; set; }

        [MaxLength(100)]
        public string? ReferenceNo { get; set; }

        [MinLength(2)]
        public List<JournalEntryLineRequestDto> Lines { get; set; } = new List<JournalEntryLineRequestDto>();
    }

    public class BulkCreateJournalEntriesRequestDto
    {
        [MinLength(1)]
        public List<CreateJournalEntryRequestDto> Entries { get; set; } = new List<CreateJournalEntryRequestDto>();
    }

    public class JournalEntryLineResponseDto
    {
        public long JournalEntryLineId { get; set; }
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string? LineDescription { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
    }

    public class JournalEntryResponseDto
    {
        public long JournalEntryId { get; set; }
        public DateTime EntryDate { get; set; }
        public string? Description { get; set; }
        public string? ReferenceNo { get; set; }
        public string Status { get; set; } = string.Empty;
        public Guid CreatedByUserId { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? PostedAt { get; set; }
        public DateTime? ReversedAt { get; set; }
        public decimal DebitTotal { get; set; }
        public decimal CreditTotal { get; set; }
        public List<JournalEntryLineResponseDto> Lines { get; set; } = new List<JournalEntryLineResponseDto>();
    }

    public class PagedResultDto<T>
    {
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalCount { get; set; }
        public List<T> Items { get; set; } = new List<T>();
    }

    public class JournalEntryQueryRequestDto
    {
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }

        [MaxLength(20)]
        public string? Status { get; set; }

        public int? AccountId { get; set; }

        [MaxLength(200)]
        public string? Search { get; set; }

        [Range(1, int.MaxValue)]
        public int Page { get; set; } = 1;

        [Range(1, 200)]
        public int PageSize { get; set; } = 20;

        [MaxLength(30)]
        public string? Sort { get; set; } = "entryDate_desc";
    }

    public class CreateAccountingPeriodRequestDto
    {
        [Required]
        public int PeriodId { get; set; }

        [Required]
        public DateTime StartDate { get; set; }

        [Required]
        public DateTime EndDate { get; set; }
    }

    public class AccountingPeriodResponseDto
    {
        public int PeriodId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsClosed { get; set; }
        public DateTime? ClosedAt { get; set; }
        public Guid? ClosedByUserId { get; set; }
    }

    public class ReportItemDto
    {
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string AccountType { get; set; } = string.Empty;
        public decimal DebitTotal { get; set; }
        public decimal CreditTotal { get; set; }
        public decimal Balance { get; set; }
    }

    public class TrialBalanceResponseDto
    {
        public int PeriodId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal TotalDebit { get; set; }
        public decimal TotalCredit { get; set; }
        public List<ReportItemDto> Items { get; set; } = new List<ReportItemDto>();
    }

    public class ProfitLossResponseDto
    {
        public int PeriodId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal TotalRevenue { get; set; }
        public decimal TotalExpense { get; set; }
        public decimal NetProfit { get; set; }
        public List<ReportItemDto> Items { get; set; } = new List<ReportItemDto>();
    }

    public class BalanceSheetResponseDto
    {
        public int PeriodId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal TotalAssets { get; set; }
        public decimal TotalLiabilities { get; set; }
        public decimal TotalEquity { get; set; }
        public List<ReportItemDto> Items { get; set; } = new List<ReportItemDto>();
    }

    public class AccountLedgerLineDto
    {
        public DateTime EntryDate { get; set; }
        public long JournalEntryId { get; set; }
        public string? ReferenceNo { get; set; }
        public string? EntryDescription { get; set; }
        public string? LineDescription { get; set; }
        public decimal Debit { get; set; }
        public decimal Credit { get; set; }
        public decimal RunningBalance { get; set; }
    }

    public class AccountLedgerResponseDto
    {
        public int PeriodId { get; set; }
        public int AccountId { get; set; }
        public string AccountCode { get; set; } = string.Empty;
        public string AccountName { get; set; } = string.Empty;
        public string AccountType { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public decimal OpeningBalance { get; set; }
        public decimal ClosingBalance { get; set; }
        public List<AccountLedgerLineDto> Lines { get; set; } = new List<AccountLedgerLineDto>();
    }

    public class AuditLogResponseDto
    {
        public long AuditLogId { get; set; }
        public Guid? UserId { get; set; }
        public string Action { get; set; } = string.Empty;
        public string? EntityName { get; set; }
        public string? EntityId { get; set; }
        public DateTime Timestamp { get; set; }
        public string? IpAddress { get; set; }
        public string? DetailsJson { get; set; }
    }
}

