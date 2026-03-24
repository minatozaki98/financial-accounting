using Microsoft.EntityFrameworkCore;
using MODEL.Entities;

namespace MODEL
{
    public class DataContext : DbContext
    {
        public DataContext(DbContextOptions<DataContext> options) : base(options)
        {
        }

        public virtual DbSet<Quotation> Quotation => Set<Quotation>();
        public DbSet<Users> Users => Set<Users>();
        public DbSet<Role> Role => Set<Role>();

        public DbSet<FinancialRole> FinancialRoles => Set<FinancialRole>();
        public DbSet<UserRole> UserRoles => Set<UserRole>();
        public DbSet<ChartOfAccount> ChartOfAccounts => Set<ChartOfAccount>();
        public DbSet<JournalEntry> JournalEntries => Set<JournalEntry>();
        public DbSet<JournalEntryLine> JournalEntryLines => Set<JournalEntryLine>();
        public DbSet<AccountingPeriod> AccountingPeriods => Set<AccountingPeriod>();
        public DbSet<Currency> Currencies => Set<Currency>();
        public DbSet<FinancialReport> Reports => Set<FinancialReport>();
        public DbSet<FinancialReportItem> ReportItems => Set<FinancialReportItem>();
        public DbSet<LedgerBalance> LedgerBalances => Set<LedgerBalance>();
        public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Quotation>(entity =>
            {
                entity.ToTable("Quotation", "dbo");
            });

            modelBuilder.Entity<Users>(entity =>
            {
                entity.ToTable("Users","dbo");
            });

            modelBuilder.Entity<Role>(entity =>
            {
                entity.ToTable("Role","dbo");
            });

            modelBuilder.Entity<FinancialRole>(entity =>
            {
                entity.ToTable("Roles", "dbo");
                entity.Property(x => x.RoleName).HasMaxLength(50);
                entity.Property(x => x.Description).HasMaxLength(200);
                entity.HasIndex(x => x.RoleName).IsUnique();
            });

            modelBuilder.Entity<UserRole>(entity =>
            {
                entity.ToTable("UserRoles", "dbo");
                entity.HasIndex(x => new { x.UserId, x.RoleId }).IsUnique();
                entity.HasOne(x => x.User)
                    .WithMany(x => x.UserRoles)
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.Role)
                    .WithMany(x => x.UserRoles)
                    .HasForeignKey(x => x.RoleId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<ChartOfAccount>(entity =>
            {
                entity.ToTable("ChartOfAccounts", "dbo");
                entity.Property(x => x.AccountCode).HasMaxLength(20);
                entity.Property(x => x.AccountName).HasMaxLength(200);
                entity.Property(x => x.AccountType).HasMaxLength(20);
                entity.HasIndex(x => x.AccountCode).IsUnique();
                entity.HasIndex(x => x.AccountType);
            });

            modelBuilder.Entity<JournalEntry>(entity =>
            {
                entity.ToTable("JournalEntries", "dbo");
                entity.Property(x => x.EntryDate).HasColumnType("date");
                entity.Property(x => x.Description).HasMaxLength(500);
                entity.Property(x => x.ReferenceNo).HasMaxLength(100);
                entity.Property(x => x.Status).HasMaxLength(20);
                entity.HasIndex(x => x.EntryDate);
                entity.HasIndex(x => x.ReferenceNo);
                entity.HasIndex(x => x.Status);
                entity.HasIndex(x => new { x.Status, x.EntryDate, x.JournalEntryId });
                entity.HasOne(x => x.CreatedByUser)
                    .WithMany(x => x.CreatedJournalEntries)
                    .HasForeignKey(x => x.CreatedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<JournalEntryLine>(entity =>
            {
                entity.ToTable("JournalEntryLines", "dbo");
                entity.Property(x => x.LineDescription).HasMaxLength(500);
                entity.Property(x => x.Debit).HasPrecision(18, 2);
                entity.Property(x => x.Credit).HasPrecision(18, 2);
                entity.HasIndex(x => x.JournalEntryId);
                entity.HasIndex(x => x.AccountId);
                entity.HasIndex(x => new { x.AccountId, x.JournalEntryId, x.JournalEntryLineId });
                entity.HasOne(x => x.JournalEntry)
                    .WithMany(x => x.Lines)
                    .HasForeignKey(x => x.JournalEntryId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.Account)
                    .WithMany(x => x.JournalEntryLines)
                    .HasForeignKey(x => x.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<AccountingPeriod>(entity =>
            {
                entity.ToTable("AccountingPeriods", "dbo");
                entity.Property(x => x.StartDate).HasColumnType("date");
                entity.Property(x => x.EndDate).HasColumnType("date");
                entity.HasIndex(x => x.IsClosed);
                entity.HasOne(x => x.ClosedByUser)
                    .WithMany(x => x.ClosedPeriods)
                    .HasForeignKey(x => x.ClosedByUserId)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            modelBuilder.Entity<Currency>(entity =>
            {
                entity.ToTable("Currencies", "dbo");
                entity.Property(x => x.CurrencyCode).HasMaxLength(10);
                entity.Property(x => x.Name).HasMaxLength(50);
                entity.Property(x => x.Symbol).HasMaxLength(10);
            });

            modelBuilder.Entity<FinancialReport>(entity =>
            {
                entity.ToTable("Reports", "dbo");
                entity.Property(x => x.ReportType).HasMaxLength(50);
                entity.HasIndex(x => x.ReportType);
                entity.HasOne(x => x.Period)
                    .WithMany(x => x.Reports)
                    .HasForeignKey(x => x.PeriodId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.GeneratedByUser)
                    .WithMany(x => x.GeneratedReports)
                    .HasForeignKey(x => x.GeneratedByUserId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<FinancialReportItem>(entity =>
            {
                entity.ToTable("ReportItems", "dbo");
                entity.Property(x => x.DebitTotal).HasPrecision(18, 2);
                entity.Property(x => x.CreditTotal).HasPrecision(18, 2);
                entity.Property(x => x.Balance).HasPrecision(18, 2);
                entity.HasOne(x => x.Report)
                    .WithMany(x => x.ReportItems)
                    .HasForeignKey(x => x.ReportId)
                    .OnDelete(DeleteBehavior.Cascade);
                entity.HasOne(x => x.Account)
                    .WithMany(x => x.ReportItems)
                    .HasForeignKey(x => x.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<LedgerBalance>(entity =>
            {
                entity.ToTable("LedgerBalances", "dbo");
                entity.Property(x => x.DebitTotal).HasPrecision(18, 2);
                entity.Property(x => x.CreditTotal).HasPrecision(18, 2);
                entity.Property(x => x.Balance).HasPrecision(18, 2);
                entity.HasIndex(x => new { x.AccountId, x.PeriodId }).IsUnique();
                entity.HasOne(x => x.Account)
                    .WithMany(x => x.LedgerBalances)
                    .HasForeignKey(x => x.AccountId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(x => x.Period)
                    .WithMany(x => x.LedgerBalances)
                    .HasForeignKey(x => x.PeriodId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<AuditLog>(entity =>
            {
                entity.ToTable("AuditLogs", "dbo");
                entity.Property(x => x.Action).HasMaxLength(100);
                entity.Property(x => x.EntityName).HasMaxLength(100);
                entity.Property(x => x.EntityId).HasMaxLength(50);
                entity.Property(x => x.IpAddress).HasMaxLength(50);
                entity.HasIndex(x => x.Action);
                entity.HasIndex(x => x.Timestamp);
                entity.HasOne(x => x.User)
                    .WithMany(x => x.AuditLogs)
                    .HasForeignKey(x => x.UserId)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            base.OnModelCreating(modelBuilder);
        }
    }
}
