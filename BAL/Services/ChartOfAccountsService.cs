using BAL.IServices;
using BAL.Shared;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;

namespace BAL.Services
{
    internal class ChartOfAccountsService : IChartOfAccountsService
    {
        private static readonly HashSet<string> AllowedAccountTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "Asset",
            "Liability",
            "Equity",
            "Revenue",
            "Expense"
        };

        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;
        private readonly FinancialReadCache _cache;

        public ChartOfAccountsService(DataContext context, IAuditLogService auditLogService, FinancialReadCache cache)
        {
            _context = context;
            _auditLogService = auditLogService;
            _cache = cache;
        }

        public async Task<List<AccountResponseDto>> GetAccountsAsync(string? type, bool? isActive, string? search)
        {
            var cacheKey = $"{type?.Trim()}|{isActive?.ToString() ?? ""}|{search?.Trim()}";
            var accounts = await _cache.GetOrCreateAccountsAsync(
                cacheKey,
                () => GetAccountsUncachedAsync(type, isActive, search));

            return accounts.Select(CloneAccount).ToList();
        }

        private async Task<List<AccountResponseDto>> GetAccountsUncachedAsync(string? type, bool? isActive, string? search)
        {
            var query = _context.ChartOfAccounts.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(type))
            {
                query = query.Where(x => x.AccountType == type);
            }

            if (isActive.HasValue)
            {
                query = query.Where(x => x.IsActive == isActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var keyword = search.Trim();
                query = query.Where(x =>
                    x.AccountCode.Contains(keyword) ||
                    x.AccountName.Contains(keyword));
            }

            var entities = await query
                .OrderBy(x => x.AccountCode)
                .ToListAsync();

            return entities.Select(MapToDto).ToList();
        }

        public async Task<AccountResponseDto?> GetByIdAsync(int accountId)
        {
            var entity = await _context.ChartOfAccounts
                .AsNoTracking()
                .Where(x => x.AccountId == accountId)
                .FirstOrDefaultAsync();

            return entity == null ? null : MapToDto(entity);
        }

        public async Task<AccountBalanceResponseDto?> GetBalanceAsync(int accountId)
        {
            var account = await _context.ChartOfAccounts
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.AccountId == accountId);

            if (account == null)
            {
                return null;
            }

            var aggregate = await (
                    from line in _context.JournalEntryLines
                    join entry in _context.JournalEntries on line.JournalEntryId equals entry.JournalEntryId
                    where line.AccountId == accountId && entry.Status == "Posted"
                    group line by 1
                into grouped
                    select new
                    {
                        DebitTotal = grouped.Sum(x => x.Debit),
                        CreditTotal = grouped.Sum(x => x.Credit)
                    })
                .FirstOrDefaultAsync();

            var debitTotal = aggregate?.DebitTotal ?? 0m;
            var creditTotal = aggregate?.CreditTotal ?? 0m;

            return new AccountBalanceResponseDto
            {
                AccountId = account.AccountId,
                AccountCode = account.AccountCode,
                AccountName = account.AccountName,
                AccountType = account.AccountType,
                DebitTotal = debitTotal,
                CreditTotal = creditTotal,
                Balance = NormalizeBalance(account.AccountType, debitTotal, creditTotal)
            };
        }

        public async Task<AccountResponseDto> CreateAsync(CreateAccountRequestDto request, Guid actorUserId, string? ipAddress)
        {
            var accountType = NormalizeAccountType(request.AccountType);

            var exists = await _context.ChartOfAccounts.AnyAsync(x => x.AccountCode == request.AccountCode);
            if (exists)
            {
                throw new InvalidOperationException($"Account code '{request.AccountCode}' already exists.");
            }

            var now = DateTime.UtcNow;
            var entity = new ChartOfAccount
            {
                AccountCode = request.AccountCode.Trim(),
                AccountName = request.AccountName.Trim(),
                AccountType = accountType,
                IsActive = request.IsActive,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _context.ChartOfAccounts.AddAsync(entity);
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "CREATE_ACCOUNT",
                "ChartOfAccounts",
                entity.AccountId.ToString(),
                ipAddress,
                new { entity.AccountCode, entity.AccountName, entity.AccountType });
            _cache.InvalidateAccounts();

            return MapToDto(entity);
        }

        public async Task<bool> UpdateAsync(int accountId, UpdateAccountRequestDto request, Guid actorUserId, string? ipAddress)
        {
            var entity = await _context.ChartOfAccounts.FirstOrDefaultAsync(x => x.AccountId == accountId);
            if (entity == null)
            {
                return false;
            }

            entity.AccountName = request.AccountName.Trim();
            entity.AccountType = NormalizeAccountType(request.AccountType);
            entity.IsActive = request.IsActive;
            entity.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "UPDATE_ACCOUNT",
                "ChartOfAccounts",
                accountId.ToString(),
                ipAddress,
                new { entity.AccountName, entity.AccountType, entity.IsActive });
            _cache.InvalidateAccounts();

            return true;
        }

        private static AccountResponseDto MapToDto(ChartOfAccount account)
        {
            return new AccountResponseDto
            {
                AccountId = account.AccountId,
                AccountCode = account.AccountCode,
                AccountName = account.AccountName,
                AccountType = account.AccountType,
                IsActive = account.IsActive,
                CreatedAt = account.CreatedAt,
                UpdatedAt = account.UpdatedAt
            };
        }

        private static AccountResponseDto CloneAccount(AccountResponseDto account)
        {
            return new AccountResponseDto
            {
                AccountId = account.AccountId,
                AccountCode = account.AccountCode,
                AccountName = account.AccountName,
                AccountType = account.AccountType,
                IsActive = account.IsActive,
                CreatedAt = account.CreatedAt,
                UpdatedAt = account.UpdatedAt
            };
        }

        private static string NormalizeAccountType(string accountType)
        {
            if (string.IsNullOrWhiteSpace(accountType))
            {
                throw new InvalidOperationException("AccountType is required.");
            }

            var normalized = accountType.Trim();
            if (!AllowedAccountTypes.Contains(normalized))
            {
                throw new InvalidOperationException("AccountType must be one of: Asset, Liability, Equity, Revenue, Expense.");
            }

            return normalized.Substring(0, 1).ToUpperInvariant() + normalized.Substring(1).ToLowerInvariant();
        }

        private static decimal NormalizeBalance(string accountType, decimal debitTotal, decimal creditTotal)
        {
            if (accountType.Equals("Liability", StringComparison.OrdinalIgnoreCase) ||
                accountType.Equals("Equity", StringComparison.OrdinalIgnoreCase) ||
                accountType.Equals("Revenue", StringComparison.OrdinalIgnoreCase))
            {
                return creditTotal - debitTotal;
            }

            return debitTotal - creditTotal;
        }
    }
}
