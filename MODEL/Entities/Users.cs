using MODEL.ApplicationConfig;
using System.ComponentModel.DataAnnotations;

namespace MODEL.Entities
{
    public class Users : Common
    {
        [Key]
        public Guid UserId { get; set; }
        public string Username { get; set; } = null!;
        public string Email { get; set; } = null!;
        public bool IsActive { get; set; } = true;
        public Guid? RoleId { get; set; } = new Guid("E2A3172D-8E4A-4B98-8CFA-1F25B0ED0A31");
        public byte[] PasswordHash { get; set; } = null!;
        public byte[] PasswordSalt { get; set; } = null!;
        public string FullName { get; set; } = null!;
        public string? DisplayName { get; set; }
        public string PhoneNumber { get; set; } = null!;
        public string ProfileUrl { get; set; } = string.Empty;
        public DateTime? LastAcvite { get; set; }

        public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
        public ICollection<JournalEntry> CreatedJournalEntries { get; set; } = new List<JournalEntry>();
        public ICollection<AccountingPeriod> ClosedPeriods { get; set; } = new List<AccountingPeriod>();
        public ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();
        public ICollection<FinancialReport> GeneratedReports { get; set; } = new List<FinancialReport>();
    }
}
