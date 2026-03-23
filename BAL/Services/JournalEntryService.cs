using BAL.IServices;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;

namespace BAL.Services
{
    internal class JournalEntryService : IJournalEntryService
    {
        private const string DraftStatus = "Draft";
        private const string PostedStatus = "Posted";
        private const string ReversedStatus = "Reversed";
        private const string JournalEntriesEntityName = "JournalEntries";

        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;

        public JournalEntryService(DataContext context, IAuditLogService auditLogService)
        {
            _context = context;
            _auditLogService = auditLogService;
        }

        public async Task<JournalEntryResponseDto> CreateDraftAsync(CreateJournalEntryRequestDto request, Guid actorUserId, string? ipAddress)
        {
            await ValidateLinesAsync(request.Lines);

            var entity = new JournalEntry
            {
                EntryDate = request.EntryDate.Date,
                Description = request.Description?.Trim(),
                ReferenceNo = request.ReferenceNo?.Trim(),
                Status = DraftStatus,
                CreatedByUserId = actorUserId,
                CreatedAt = DateTime.UtcNow
            };

            foreach (var line in request.Lines)
            {
                entity.Lines.Add(new JournalEntryLine
                {
                    AccountId = line.AccountId,
                    LineDescription = line.LineDescription?.Trim(),
                    Debit = decimal.Round(line.Debit, 2),
                    Credit = decimal.Round(line.Credit, 2)
                });
            }

            await _context.JournalEntries.AddAsync(entity);
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "CREATE_DRAFT_ENTRY",
                JournalEntriesEntityName,
                entity.JournalEntryId.ToString(),
                ipAddress,
                new { entity.EntryDate, entity.ReferenceNo, Lines = entity.Lines.Count });

            var saved = await GetByIdAsync(entity.JournalEntryId);
            return saved!;
        }

        public async Task<List<long>> BulkCreateDraftAsync(BulkCreateJournalEntriesRequestDto request, Guid actorUserId, string? ipAddress)
        {
            if (request.Entries.Count == 0)
            {
                throw new InvalidOperationException("At least one journal entry is required.");
            }

            var entities = new List<JournalEntry>();
            foreach (var entry in request.Entries)
            {
                await ValidateLinesAsync(entry.Lines);

                var entity = new JournalEntry
                {
                    EntryDate = entry.EntryDate.Date,
                    Description = entry.Description?.Trim(),
                    ReferenceNo = entry.ReferenceNo?.Trim(),
                    Status = DraftStatus,
                    CreatedByUserId = actorUserId,
                    CreatedAt = DateTime.UtcNow
                };

                foreach (var line in entry.Lines)
                {
                    entity.Lines.Add(new JournalEntryLine
                    {
                        AccountId = line.AccountId,
                        LineDescription = line.LineDescription?.Trim(),
                        Debit = decimal.Round(line.Debit, 2),
                        Credit = decimal.Round(line.Credit, 2)
                    });
                }

                entities.Add(entity);
            }

            await _context.JournalEntries.AddRangeAsync(entities);
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "BULK_CREATE_DRAFT_ENTRIES",
                JournalEntriesEntityName,
                entities.Count.ToString(),
                ipAddress,
                new { Count = entities.Count });

            return entities.Select(x => x.JournalEntryId).ToList();
        }

        public async Task<JournalEntryResponseDto?> GetByIdAsync(long journalEntryId)
        {
            var entity = await _context.JournalEntries
                .AsNoTracking()
                .Include(x => x.Lines)
                .ThenInclude(x => x.Account)
                .FirstOrDefaultAsync(x => x.JournalEntryId == journalEntryId);

            return entity == null ? null : MapToDto(entity);
        }

        public async Task<PagedResultDto<JournalEntryResponseDto>> GetPagedAsync(JournalEntryQueryDto query)
        {
            var page = query.Page < 1 ? 1 : query.Page;
            var pageSize = query.PageSize < 1 ? 20 : Math.Min(query.PageSize, 200);

            var entriesQuery = _context.JournalEntries
                .AsNoTracking()
                .AsQueryable();

            if (query.From.HasValue)
            {
                entriesQuery = entriesQuery.Where(x => x.EntryDate >= query.From.Value.Date);
            }

            if (query.To.HasValue)
            {
                entriesQuery = entriesQuery.Where(x => x.EntryDate <= query.To.Value.Date);
            }

            if (!string.IsNullOrWhiteSpace(query.Status))
            {
                entriesQuery = entriesQuery.Where(x => x.Status == query.Status);
            }

            if (query.AccountId.HasValue)
            {
                entriesQuery = entriesQuery.Where(x => x.Lines.Any(l => l.AccountId == query.AccountId.Value));
            }

            if (!string.IsNullOrWhiteSpace(query.Search))
            {
                var keyword = query.Search.Trim();
                entriesQuery = entriesQuery.Where(x =>
                    (x.Description != null && x.Description.Contains(keyword)) ||
                    (x.ReferenceNo != null && x.ReferenceNo.Contains(keyword)));
            }

            var orderedQuery = query.Sort?.ToLowerInvariant() switch
            {
                "entrydate_asc" => entriesQuery.OrderBy(x => x.EntryDate).ThenBy(x => x.JournalEntryId),
                "entrydate_desc" => entriesQuery.OrderByDescending(x => x.EntryDate).ThenByDescending(x => x.JournalEntryId),
                _ => entriesQuery.OrderByDescending(x => x.EntryDate).ThenByDescending(x => x.JournalEntryId)
            };

            var totalCount = await entriesQuery.CountAsync();
            var pageIds = await orderedQuery
                .Select(x => x.JournalEntryId)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var entries = await _context.JournalEntries
                .AsNoTracking()
                .Where(x => pageIds.Contains(x.JournalEntryId))
                .Include(x => x.Lines)
                .ThenInclude(x => x.Account)
                .ToListAsync();

            var indexMap = pageIds
                .Select((id, index) => new { id, index })
                .ToDictionary(x => x.id, x => x.index);
            entries = entries.OrderBy(x => indexMap[x.JournalEntryId]).ToList();

            return new PagedResultDto<JournalEntryResponseDto>
            {
                Page = page,
                PageSize = pageSize,
                TotalCount = totalCount,
                Items = entries.Select(MapToDto).ToList()
            };
        }

        public async Task<bool> PostAsync(long journalEntryId, Guid actorUserId, string? ipAddress)
        {
            var entry = await _context.JournalEntries
                .Include(x => x.Lines)
                .FirstOrDefaultAsync(x => x.JournalEntryId == journalEntryId);

            if (entry == null || !string.Equals(entry.Status, DraftStatus, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            var period = await GetPeriodForDateAsync(entry.EntryDate);
            if (period != null && period.IsClosed)
            {
                throw new InvalidOperationException("Cannot post journal entry in a closed accounting period.");
            }

            var debitTotal = entry.Lines.Sum(x => x.Debit);
            var creditTotal = entry.Lines.Sum(x => x.Credit);
            if (decimal.Round(debitTotal, 2) != decimal.Round(creditTotal, 2) || debitTotal <= 0m)
            {
                throw new InvalidOperationException("Journal entry must be balanced before posting.");
            }

            entry.Status = PostedStatus;
            entry.PostedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            if (period != null)
            {
                await RefreshLedgerBalancesForPeriodAsync(period.PeriodId);
            }

            await _auditLogService.WriteAsync(
                actorUserId,
                "POST_ENTRY",
                JournalEntriesEntityName,
                journalEntryId.ToString(),
                ipAddress,
                new { debitTotal, creditTotal });

            return true;
        }

        public async Task<long> ReverseAsync(long journalEntryId, Guid actorUserId, string? ipAddress)
        {
            var original = await _context.JournalEntries
                .Include(x => x.Lines)
                .FirstOrDefaultAsync(x => x.JournalEntryId == journalEntryId);

            if (original == null)
            {
                throw new InvalidOperationException("Journal entry was not found.");
            }

            if (!string.Equals(original.Status, PostedStatus, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Only posted journal entries can be reversed.");
            }

            if (original.ReversedAt.HasValue)
            {
                throw new InvalidOperationException("This journal entry has already been reversed.");
            }

            var period = await GetPeriodForDateAsync(original.EntryDate);
            if (period != null && period.IsClosed)
            {
                throw new InvalidOperationException("Cannot reverse entry in a closed accounting period.");
            }

            var reversal = new JournalEntry
            {
                EntryDate = original.EntryDate,
                Description = $"Reversal of #{original.JournalEntryId}: {original.Description}",
                ReferenceNo = string.IsNullOrWhiteSpace(original.ReferenceNo) ? $"REV-{original.JournalEntryId}" : $"REV-{original.ReferenceNo}",
                Status = PostedStatus,
                CreatedByUserId = actorUserId,
                CreatedAt = DateTime.UtcNow,
                PostedAt = DateTime.UtcNow
            };

            foreach (var line in original.Lines)
            {
                reversal.Lines.Add(new JournalEntryLine
                {
                    AccountId = line.AccountId,
                    LineDescription = line.LineDescription,
                    Debit = line.Credit,
                    Credit = line.Debit
                });
            }

            original.Status = ReversedStatus;
            original.ReversedAt = DateTime.UtcNow;

            await _context.JournalEntries.AddAsync(reversal);
            await _context.SaveChangesAsync();

            if (period != null)
            {
                await RefreshLedgerBalancesForPeriodAsync(period.PeriodId);
            }

            await _auditLogService.WriteAsync(
                actorUserId,
                "REVERSE_ENTRY",
                JournalEntriesEntityName,
                journalEntryId.ToString(),
                ipAddress,
                new { reversingEntryId = reversal.JournalEntryId });

            return reversal.JournalEntryId;
        }

        public async Task<bool> DeleteDraftAsync(long journalEntryId, Guid actorUserId, string? ipAddress)
        {
            var entity = await _context.JournalEntries
                .Include(x => x.Lines)
                .FirstOrDefaultAsync(x => x.JournalEntryId == journalEntryId);

            if (entity == null || !string.Equals(entity.Status, DraftStatus, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            _context.JournalEntryLines.RemoveRange(entity.Lines);
            _context.JournalEntries.Remove(entity);
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "DELETE_DRAFT_ENTRY",
                JournalEntriesEntityName,
                journalEntryId.ToString(),
                ipAddress);

            return true;
        }

        private async Task ValidateLinesAsync(List<JournalEntryLineRequestDto> lines)
        {
            if (lines.Count < 2)
            {
                throw new InvalidOperationException("Journal entry must have at least two lines.");
            }

            foreach (var line in lines)
            {
                var hasDebit = line.Debit > 0m;
                var hasCredit = line.Credit > 0m;
                if (hasDebit == hasCredit)
                {
                    throw new InvalidOperationException("Each line must contain either a debit amount or a credit amount.");
                }
            }

            var accountIds = lines.Select(x => x.AccountId).Distinct().ToList();
            var activeIds = await _context.ChartOfAccounts
                .Where(x => accountIds.Contains(x.AccountId) && x.IsActive)
                .Select(x => x.AccountId)
                .ToListAsync();

            if (activeIds.Count != accountIds.Count)
            {
                throw new InvalidOperationException("One or more account IDs are invalid or inactive.");
            }
        }

        private async Task<AccountingPeriod?> GetPeriodForDateAsync(DateTime entryDate)
        {
            var date = entryDate.Date;
            return await _context.AccountingPeriods
                .FirstOrDefaultAsync(x => x.StartDate <= date && x.EndDate >= date);
        }

        private async Task RefreshLedgerBalancesForPeriodAsync(int periodId)
        {
            var period = await _context.AccountingPeriods.AsNoTracking().FirstOrDefaultAsync(x => x.PeriodId == periodId);
            if (period == null)
            {
                return;
            }

            var aggregates = await (
                    from entry in _context.JournalEntries
                    join line in _context.JournalEntryLines on entry.JournalEntryId equals line.JournalEntryId
                    join account in _context.ChartOfAccounts on line.AccountId equals account.AccountId
                    where entry.Status == PostedStatus &&
                          entry.EntryDate >= period.StartDate &&
                          entry.EntryDate <= period.EndDate
                    group new { line, account } by new { line.AccountId, account.AccountType }
                into grouped
                    select new
                    {
                        grouped.Key.AccountId,
                        grouped.Key.AccountType,
                        DebitTotal = grouped.Sum(x => (double)x.line.Debit),
                        CreditTotal = grouped.Sum(x => (double)x.line.Credit)
                    })
                .ToListAsync();

            var existing = await _context.LedgerBalances
                .Where(x => x.PeriodId == periodId)
                .ToListAsync();

            var existingMap = existing.ToDictionary(x => x.AccountId, x => x);
            var aggregateIds = aggregates.Select(x => x.AccountId).ToHashSet();

            foreach (var aggregate in aggregates)
            {
                if (!existingMap.TryGetValue(aggregate.AccountId, out var row))
                {
                    row = new LedgerBalance
                    {
                        PeriodId = periodId,
                        AccountId = aggregate.AccountId
                    };
                    _context.LedgerBalances.Add(row);
                }

                row.DebitTotal = decimal.Round(Convert.ToDecimal(aggregate.DebitTotal), 2);
                row.CreditTotal = decimal.Round(Convert.ToDecimal(aggregate.CreditTotal), 2);
                row.Balance = NormalizeBalance(aggregate.AccountType, row.DebitTotal, row.CreditTotal);
                row.UpdatedAt = DateTime.UtcNow;
            }

            foreach (var stale in existing.Where(x => !aggregateIds.Contains(x.AccountId)))
            {
                _context.LedgerBalances.Remove(stale);
            }

            await _context.SaveChangesAsync();
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

        private static JournalEntryResponseDto MapToDto(JournalEntry entry)
        {
            var lines = entry.Lines.Select(x => new JournalEntryLineResponseDto
            {
                JournalEntryLineId = x.JournalEntryLineId,
                AccountId = x.AccountId,
                AccountCode = x.Account?.AccountCode ?? string.Empty,
                AccountName = x.Account?.AccountName ?? string.Empty,
                LineDescription = x.LineDescription,
                Debit = x.Debit,
                Credit = x.Credit
            }).ToList();

            return new JournalEntryResponseDto
            {
                JournalEntryId = entry.JournalEntryId,
                EntryDate = entry.EntryDate,
                Description = entry.Description,
                ReferenceNo = entry.ReferenceNo,
                Status = entry.Status,
                CreatedByUserId = entry.CreatedByUserId,
                CreatedAt = entry.CreatedAt,
                PostedAt = entry.PostedAt,
                ReversedAt = entry.ReversedAt,
                DebitTotal = lines.Sum(x => x.Debit),
                CreditTotal = lines.Sum(x => x.Credit),
                Lines = lines
            };
        }
    }
}
