using BAL.Shared;
using MODEL;
using MODEL.Entities;

namespace FinancialAccounting.IntegrationTests.Fixtures;

public static class TestDataFixture
{
    public const string AdminUsername = "admin";
    public const string FinanceManagerUsername = "finance-manager";
    public const string UserUsername = "normal-user";
    public const string AuditorUsername = "auditor-user";
    public const string DefaultPassword = "Admin@123";
    public const int OpenPeriodId = 202601;
    public const int ClosedPeriodId = 202512;

    public static int AssetAccountId { get; private set; }
    public static int LiabilityAccountId { get; private set; }
    public static long DraftEntryId { get; private set; }
    public static long PostedEntryId { get; private set; }
    public static long MatrixDraftEntryId { get; private set; }
    public static long MatrixReverseAdminEntryId { get; private set; }
    public static long MatrixReverseFinanceEntryId { get; private set; }

    public static void Seed(DataContext context)
    {
        if (context.Users.Any())
        {
            return;
        }

        var adminRole = new FinancialRole { RoleName = "Admin", Description = "Admin" };
        var userRole = new FinancialRole { RoleName = "User", Description = "User" };
        var auditorRole = new FinancialRole { RoleName = "Auditor", Description = "Auditor" };
        var financeRole = new FinancialRole { RoleName = "FinanceManager", Description = "Finance" };

        context.FinancialRoles.AddRange(adminRole, userRole, auditorRole, financeRole);
        context.SaveChanges();

        var admin = CreateUser(AdminUsername, "admin@local.invalid");
        var finance = CreateUser(FinanceManagerUsername, "fm@local.invalid");
        var user = CreateUser(UserUsername, "user@local.invalid");
        var auditor = CreateUser(AuditorUsername, "auditor@local.invalid");

        context.Users.AddRange(admin, finance, user, auditor);
        context.SaveChanges();

        context.UserRoles.AddRange(
            new UserRole { UserId = admin.UserId, RoleId = adminRole.RoleId },
            new UserRole { UserId = finance.UserId, RoleId = financeRole.RoleId },
            new UserRole { UserId = user.UserId, RoleId = userRole.RoleId },
            new UserRole { UserId = auditor.UserId, RoleId = auditorRole.RoleId });

        var openPeriod = new AccountingPeriod
        {
            PeriodId = OpenPeriodId,
            StartDate = new DateTime(2026, 1, 1),
            EndDate = new DateTime(2026, 12, 31),
            IsClosed = false
        };

        var closedPeriod = new AccountingPeriod
        {
            PeriodId = ClosedPeriodId,
            StartDate = new DateTime(2025, 1, 1),
            EndDate = new DateTime(2025, 12, 31),
            IsClosed = true,
            ClosedAt = DateTime.UtcNow,
            ClosedByUserId = admin.UserId
        };

        context.AccountingPeriods.AddRange(openPeriod, closedPeriod);

        var accounts = new[]
        {
            new ChartOfAccount { AccountCode = "A1000", AccountName = "Cash", AccountType = "Asset", IsActive = true },
            new ChartOfAccount { AccountCode = "L1000", AccountName = "Payable", AccountType = "Liability", IsActive = true },
            new ChartOfAccount { AccountCode = "E1000", AccountName = "Owner Equity", AccountType = "Equity", IsActive = true },
            new ChartOfAccount { AccountCode = "R1000", AccountName = "Service Revenue", AccountType = "Revenue", IsActive = true },
            new ChartOfAccount { AccountCode = "X1000", AccountName = "Office Expense", AccountType = "Expense", IsActive = true }
        };

        context.ChartOfAccounts.AddRange(accounts);
        context.SaveChanges();

        AssetAccountId = accounts.First(x => x.AccountType == "Asset").AccountId;
        LiabilityAccountId = accounts.First(x => x.AccountType == "Liability").AccountId;

        var posted = new JournalEntry
        {
            EntryDate = new DateTime(2026, 1, 15),
            Description = "Seed posted",
            ReferenceNo = "SEED-POSTED",
            Status = "Posted",
            CreatedByUserId = admin.UserId,
            CreatedAt = DateTime.UtcNow,
            PostedAt = DateTime.UtcNow
        };
        posted.Lines.Add(new JournalEntryLine
        {
            AccountId = AssetAccountId,
            Debit = 100,
            Credit = 0,
            LineDescription = "Debit cash"
        });
        posted.Lines.Add(new JournalEntryLine
        {
            AccountId = LiabilityAccountId,
            Debit = 0,
            Credit = 100,
            LineDescription = "Credit payable"
        });

        var draft = new JournalEntry
        {
            EntryDate = new DateTime(2026, 2, 1),
            Description = "Seed draft",
            ReferenceNo = "SEED-DRAFT",
            Status = "Draft",
            CreatedByUserId = admin.UserId,
            CreatedAt = DateTime.UtcNow
        };
        draft.Lines.Add(new JournalEntryLine
        {
            AccountId = AssetAccountId,
            Debit = 50,
            Credit = 0,
            LineDescription = "Debit cash"
        });
        draft.Lines.Add(new JournalEntryLine
        {
            AccountId = LiabilityAccountId,
            Debit = 0,
            Credit = 50,
            LineDescription = "Credit payable"
        });

        var matrixDraft = new JournalEntry
        {
            EntryDate = new DateTime(2026, 3, 1),
            Description = "Matrix draft",
            ReferenceNo = "SEED-MATRIX-DRAFT",
            Status = "Draft",
            CreatedByUserId = admin.UserId,
            CreatedAt = DateTime.UtcNow
        };
        matrixDraft.Lines.Add(new JournalEntryLine
        {
            AccountId = AssetAccountId,
            Debit = 60,
            Credit = 0,
            LineDescription = "Debit cash"
        });
        matrixDraft.Lines.Add(new JournalEntryLine
        {
            AccountId = LiabilityAccountId,
            Debit = 0,
            Credit = 60,
            LineDescription = "Credit payable"
        });

        var matrixPostedAdmin = new JournalEntry
        {
            EntryDate = new DateTime(2026, 3, 5),
            Description = "Matrix posted admin",
            ReferenceNo = "SEED-MATRIX-POSTED-ADMIN",
            Status = "Posted",
            CreatedByUserId = admin.UserId,
            CreatedAt = DateTime.UtcNow,
            PostedAt = DateTime.UtcNow
        };
        matrixPostedAdmin.Lines.Add(new JournalEntryLine
        {
            AccountId = AssetAccountId,
            Debit = 70,
            Credit = 0,
            LineDescription = "Debit cash"
        });
        matrixPostedAdmin.Lines.Add(new JournalEntryLine
        {
            AccountId = LiabilityAccountId,
            Debit = 0,
            Credit = 70,
            LineDescription = "Credit payable"
        });

        var matrixPostedFinance = new JournalEntry
        {
            EntryDate = new DateTime(2026, 3, 6),
            Description = "Matrix posted finance",
            ReferenceNo = "SEED-MATRIX-POSTED-FM",
            Status = "Posted",
            CreatedByUserId = admin.UserId,
            CreatedAt = DateTime.UtcNow,
            PostedAt = DateTime.UtcNow
        };
        matrixPostedFinance.Lines.Add(new JournalEntryLine
        {
            AccountId = AssetAccountId,
            Debit = 80,
            Credit = 0,
            LineDescription = "Debit cash"
        });
        matrixPostedFinance.Lines.Add(new JournalEntryLine
        {
            AccountId = LiabilityAccountId,
            Debit = 0,
            Credit = 80,
            LineDescription = "Credit payable"
        });

        context.JournalEntries.AddRange(posted, draft, matrixDraft, matrixPostedAdmin, matrixPostedFinance);
        context.SaveChanges();

        PostedEntryId = posted.JournalEntryId;
        DraftEntryId = draft.JournalEntryId;
        MatrixDraftEntryId = matrixDraft.JournalEntryId;
        MatrixReverseAdminEntryId = matrixPostedAdmin.JournalEntryId;
        MatrixReverseFinanceEntryId = matrixPostedFinance.JournalEntryId;
    }

    private static Users CreateUser(string username, string email)
    {
        CommonAuthentication.CreatePasswordHash(DefaultPassword, out var hash, out var salt);
        return new Users
        {
            UserId = Guid.NewGuid(),
            Username = username,
            Email = email,
            IsActive = true,
            PasswordHash = hash,
            PasswordSalt = salt,
            FullName = username,
            DisplayName = username,
            PhoneNumber = string.Empty,
            ProfileUrl = string.Empty,
            CreatedBy = "tests",
            UpdatedBy = "tests",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            ActiveFlag = true
        };
    }
}
