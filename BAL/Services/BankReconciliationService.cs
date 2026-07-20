using BAL.IServices;
using BAL.Shared;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;

namespace BAL.Services
{
    internal sealed class BankReconciliationService : IBankReconciliationService
    {
        private const string DraftStatus = "Draft";
        private const string MatchedStatus = "Matched";
        private const string FinalizedStatus = "Finalized";
        private const string UnmatchedStatus = "Unmatched";
        private const string AmbiguousStatus = "Ambiguous";
        private const string AutoMatchedStatus = "AutoMatched";
        private const string ManuallyMatchedStatus = "ManuallyMatched";
        private const int DateToleranceDays = 3;

        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;

        public BankReconciliationService(DataContext context, IAuditLogService auditLogService)
        {
            _context = context;
            _auditLogService = auditLogService;
        }

        public async Task<BankReconciliationResultDto> CreateAsync(
            CreateBankReconciliationRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var dateFrom = request.DateFrom.Date;
            var dateTo = request.DateTo.Date;
            if (dateFrom > dateTo)
            {
                throw new InvalidOperationException("DateFrom cannot be greater than DateTo.");
            }
            if (request.Transactions.Count == 0)
            {
                throw new InvalidOperationException("At least one bank transaction is required.");
            }

            var period = await _context.AccountingPeriods
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.PeriodId == request.PeriodId, cancellationToken)
                ?? throw new KeyNotFoundException("Accounting period was not found.");
            if (period.IsClosed)
            {
                throw new InvalidOperationException("Cannot reconcile a closed accounting period.");
            }
            if (dateFrom < period.StartDate || dateTo > period.EndDate)
            {
                throw new InvalidOperationException("Reconciliation dates must stay inside the accounting period.");
            }

            var bankAccount = await _context.ChartOfAccounts
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.AccountId == request.BankAccountId, cancellationToken)
                ?? throw new KeyNotFoundException("Bank account was not found.");
            if (!bankAccount.IsActive ||
                !bankAccount.AccountType.Equals("Asset", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Bank account must be an active asset account.");
            }

            foreach (var transaction in request.Transactions)
            {
                var date = transaction.TransactionDate.Date;
                if (date < dateFrom || date > dateTo)
                {
                    throw new InvalidOperationException("Bank transaction dates must stay inside the reconciliation range.");
                }
                if (decimal.Round(transaction.Amount, 2) == 0m)
                {
                    throw new InvalidOperationException("Bank transaction amount cannot be zero.");
                }
            }

            var reconciliation = new BankReconciliation
            {
                ReconciliationId = Guid.NewGuid(),
                PeriodId = request.PeriodId,
                BankAccountId = request.BankAccountId,
                DateFrom = dateFrom,
                DateTo = dateTo,
                Status = DraftStatus,
                CreatedByUserId = actorUserId,
                Version = 1,
                Transactions = request.Transactions.Select(item => new BankTransaction
                {
                    TransactionDate = item.TransactionDate.Date,
                    Amount = decimal.Round(item.Amount, 2),
                    ReferenceNo = NullIfWhiteSpace(item.ReferenceNo),
                    Description = NullIfWhiteSpace(item.Description),
                    MatchStatus = UnmatchedStatus
                }).ToList()
            };

            await using var transactionScope = await _context.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                _context.BankReconciliations.Add(reconciliation);
                await _context.SaveChangesAsync(cancellationToken);
                await _auditLogService.WriteAsync(
                    actorUserId,
                    "CREATE_BANK_RECONCILIATION",
                    "BankReconciliations",
                    reconciliation.ReconciliationId.ToString(),
                    ipAddress,
                    new { TransactionCount = reconciliation.Transactions.Count });
                await transactionScope.CommitAsync(cancellationToken);
                return MapResult(reconciliation, replayed: false);
            }
            catch
            {
                await transactionScope.RollbackAsync(cancellationToken);
                throw;
            }
        }

        public async Task<BankReconciliationMatchResultDto> AutoMatchAsync(
            Guid reconciliationId,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var reconciliation = await LoadForUpdateAsync(reconciliationId, cancellationToken);
            EnsureNotFinalized(reconciliation);

            var searchFrom = reconciliation.DateFrom.AddDays(-DateToleranceDays);
            var searchTo = reconciliation.DateTo.AddDays(DateToleranceDays);
            var journalEntries = await _context.JournalEntries
                .AsNoTracking()
                .Where(entry =>
                    entry.Status == "Posted" &&
                    entry.EntryDate >= searchFrom &&
                    entry.EntryDate <= searchTo &&
                    entry.Lines.Any(line => line.AccountId == reconciliation.BankAccountId))
                .Include(entry => entry.Lines)
                .ToListAsync(cancellationToken);

            var oldCandidates = reconciliation.Transactions
                .SelectMany(item => item.Candidates)
                .ToList();
            _context.BankReconciliationCandidates.RemoveRange(oldCandidates);
            foreach (var bankTransaction in reconciliation.Transactions)
            {
                bankTransaction.Candidates.Clear();
                bankTransaction.MatchedJournalEntryId = null;
                bankTransaction.MatchStatus = UnmatchedStatus;
            }

            var topCandidates = new Dictionary<long, List<BankReconciliationCandidate>>();
            foreach (var bankTransaction in reconciliation.Transactions)
            {
                var candidates = journalEntries
                    .Select(entry => new
                    {
                        Entry = entry,
                        Amount = decimal.Round(
                            entry.Lines
                                .Where(line => line.AccountId == reconciliation.BankAccountId)
                                .Sum(line => line.Debit - line.Credit),
                            2),
                        Days = Math.Abs((entry.EntryDate.Date - bankTransaction.TransactionDate.Date).Days)
                    })
                    .Where(item =>
                        item.Amount == bankTransaction.Amount &&
                        item.Days <= DateToleranceDays)
                    .Select(item => new BankReconciliationCandidate
                    {
                        BankTransactionId = bankTransaction.BankTransactionId,
                        JournalEntryId = item.Entry.JournalEntryId,
                        Score = CalculateScore(
                            bankTransaction.ReferenceNo,
                            item.Entry.ReferenceNo,
                            item.Days)
                    })
                    .OrderByDescending(item => item.Score)
                    .ThenBy(item => item.JournalEntryId)
                    .ToList();

                foreach (var candidate in candidates)
                {
                    bankTransaction.Candidates.Add(candidate);
                }
                if (candidates.Count > 0)
                {
                    var topScore = candidates[0].Score;
                    topCandidates[bankTransaction.BankTransactionId] = candidates
                        .Where(item => item.Score == topScore)
                        .ToList();
                }
            }

            var journalTopUse = topCandidates
                .SelectMany(pair => pair.Value)
                .GroupBy(item => item.JournalEntryId)
                .ToDictionary(group => group.Key, group => group.Count());
            foreach (var bankTransaction in reconciliation.Transactions)
            {
                if (!topCandidates.TryGetValue(bankTransaction.BankTransactionId, out var candidates))
                {
                    bankTransaction.MatchStatus = UnmatchedStatus;
                    continue;
                }

                if (candidates.Count == 1 &&
                    journalTopUse[candidates[0].JournalEntryId] == 1)
                {
                    candidates[0].IsSelected = true;
                    bankTransaction.MatchedJournalEntryId = candidates[0].JournalEntryId;
                    bankTransaction.MatchStatus = AutoMatchedStatus;
                }
                else
                {
                    bankTransaction.MatchStatus = AmbiguousStatus;
                }
            }

            reconciliation.Status = MatchedStatus;
            reconciliation.Version++;
            await _context.SaveChangesAsync(cancellationToken);
            await _auditLogService.WriteAsync(
                actorUserId,
                "AUTO_MATCH_BANK_RECONCILIATION",
                "BankReconciliations",
                reconciliation.ReconciliationId.ToString(),
                ipAddress,
                new
                {
                    Matched = reconciliation.Transactions.Count(IsMatched),
                    Ambiguous = reconciliation.Transactions.Count(item => item.MatchStatus == AmbiguousStatus),
                    Unmatched = reconciliation.Transactions.Count(item => item.MatchStatus == UnmatchedStatus)
                });

            return MapMatchResult(reconciliation);
        }

        public async Task<BankReconciliationResultDto> ConfirmAsync(
            Guid reconciliationId,
            ConfirmBankReconciliationMatchRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var reconciliation = await LoadForUpdateAsync(reconciliationId, cancellationToken);
            EnsureNotFinalized(reconciliation);
            EnsureVersion(reconciliation, request.ExpectedVersion);

            var bankTransaction = reconciliation.Transactions
                .FirstOrDefault(item => item.BankTransactionId == request.BankTransactionId)
                ?? throw new KeyNotFoundException("Bank transaction was not found in this reconciliation.");
            var candidate = bankTransaction.Candidates
                .FirstOrDefault(item => item.JournalEntryId == request.JournalEntryId)
                ?? throw new InvalidOperationException("Journal entry is not a valid candidate for this bank transaction.");
            if (reconciliation.Transactions.Any(item =>
                    item.BankTransactionId != bankTransaction.BankTransactionId &&
                    item.MatchedJournalEntryId == request.JournalEntryId))
            {
                throw new ResourceConflictException("Journal entry is already matched to another bank transaction.");
            }

            foreach (var item in bankTransaction.Candidates)
            {
                item.IsSelected = item.JournalEntryId == candidate.JournalEntryId;
            }
            bankTransaction.MatchedJournalEntryId = candidate.JournalEntryId;
            bankTransaction.MatchStatus = ManuallyMatchedStatus;
            reconciliation.Version++;
            await _context.SaveChangesAsync(cancellationToken);
            await _auditLogService.WriteAsync(
                actorUserId,
                "CONFIRM_BANK_RECONCILIATION_MATCH",
                "BankReconciliations",
                reconciliation.ReconciliationId.ToString(),
                ipAddress,
                new { bankTransaction.BankTransactionId, candidate.JournalEntryId });

            return MapResult(reconciliation, replayed: false);
        }

        public async Task<BankReconciliationExceptionsDto> GetExceptionsAsync(
            Guid reconciliationId,
            CancellationToken cancellationToken = default)
        {
            var reconciliation = await _context.BankReconciliations
                .AsNoTracking()
                .Include(item => item.Transactions)
                .ThenInclude(item => item.Candidates)
                .FirstOrDefaultAsync(item => item.ReconciliationId == reconciliationId, cancellationToken)
                ?? throw new KeyNotFoundException("Bank reconciliation was not found.");

            return new BankReconciliationExceptionsDto
            {
                ReconciliationId = reconciliation.ReconciliationId,
                Version = reconciliation.Version,
                Items = reconciliation.Transactions
                    .Where(item =>
                        item.MatchStatus == UnmatchedStatus ||
                        item.MatchStatus == AmbiguousStatus)
                    .OrderBy(item => item.TransactionDate)
                    .ThenBy(item => item.BankTransactionId)
                    .Select(MapTransaction)
                    .ToList()
            };
        }

        public async Task<BankReconciliationResultDto> FinalizeAsync(
            Guid reconciliationId,
            FinalizeBankReconciliationRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var reconciliation = await LoadForUpdateAsync(reconciliationId, cancellationToken);
            if (reconciliation.Status == FinalizedStatus)
            {
                if (reconciliation.FinalizeRequestId == request.RequestId)
                {
                    return MapResult(reconciliation, replayed: true);
                }

                throw new ResourceConflictException("Bank reconciliation is already finalized.");
            }

            EnsureVersion(reconciliation, request.ExpectedVersion);
            if (reconciliation.Transactions.Any(item => !IsMatched(item)))
            {
                throw new InvalidOperationException("Every bank transaction must be matched before finalization.");
            }

            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                reconciliation.Status = FinalizedStatus;
                reconciliation.FinalizedAt = DateTime.UtcNow;
                reconciliation.FinalizeRequestId = request.RequestId;
                reconciliation.Version++;
                await _context.SaveChangesAsync(cancellationToken);
                await _auditLogService.WriteAsync(
                    actorUserId,
                    "FINALIZE_BANK_RECONCILIATION",
                    "BankReconciliations",
                    reconciliation.ReconciliationId.ToString(),
                    ipAddress,
                    new { request.RequestId, reconciliation.Version });
                await transaction.CommitAsync(cancellationToken);
                return MapResult(reconciliation, replayed: false);
            }
            catch (DbUpdateConcurrencyException ex)
            {
                await transaction.RollbackAsync(cancellationToken);
                throw new ResourceConflictException($"Bank reconciliation was changed by another request: {ex.Message}");
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        }

        private async Task<BankReconciliation> LoadForUpdateAsync(
            Guid reconciliationId,
            CancellationToken cancellationToken)
        {
            return await _context.BankReconciliations
                .Include(item => item.Transactions)
                .ThenInclude(item => item.Candidates)
                .FirstOrDefaultAsync(item => item.ReconciliationId == reconciliationId, cancellationToken)
                ?? throw new KeyNotFoundException("Bank reconciliation was not found.");
        }

        private static int CalculateScore(
            string? bankReference,
            string? journalReference,
            int dayDifference)
        {
            var referenceScore =
                !string.IsNullOrWhiteSpace(bankReference) &&
                string.Equals(
                    bankReference.Trim(),
                    journalReference?.Trim(),
                    StringComparison.OrdinalIgnoreCase)
                    ? 1_000
                    : 0;
            return referenceScore + ((DateToleranceDays - dayDifference) * 10);
        }

        private static void EnsureNotFinalized(BankReconciliation reconciliation)
        {
            if (reconciliation.Status == FinalizedStatus)
            {
                throw new ResourceConflictException("Bank reconciliation is already finalized.");
            }
        }

        private static void EnsureVersion(BankReconciliation reconciliation, int expectedVersion)
        {
            if (reconciliation.Version != expectedVersion)
            {
                throw new ResourceConflictException(
                    $"Bank reconciliation version {reconciliation.Version} does not match expected version {expectedVersion}.");
            }
        }

        private static bool IsMatched(BankTransaction transaction)
        {
            return transaction.MatchStatus == AutoMatchedStatus ||
                   transaction.MatchStatus == ManuallyMatchedStatus;
        }

        private static string? NullIfWhiteSpace(string? value)
        {
            var trimmed = value?.Trim();
            return string.IsNullOrEmpty(trimmed) ? null : trimmed;
        }

        private static BankReconciliationResultDto MapResult(
            BankReconciliation reconciliation,
            bool replayed)
        {
            return new BankReconciliationResultDto
            {
                ReconciliationId = reconciliation.ReconciliationId,
                PeriodId = reconciliation.PeriodId,
                BankAccountId = reconciliation.BankAccountId,
                DateFrom = reconciliation.DateFrom,
                DateTo = reconciliation.DateTo,
                Status = reconciliation.Status,
                Version = reconciliation.Version,
                FinalizedAt = reconciliation.FinalizedAt,
                Replayed = replayed,
                Transactions = reconciliation.Transactions
                    .OrderBy(item => item.TransactionDate)
                    .ThenBy(item => item.BankTransactionId)
                    .Select(MapTransaction)
                    .ToList()
            };
        }

        private static BankReconciliationMatchResultDto MapMatchResult(
            BankReconciliation reconciliation)
        {
            return new BankReconciliationMatchResultDto
            {
                ReconciliationId = reconciliation.ReconciliationId,
                Version = reconciliation.Version,
                MatchedCount = reconciliation.Transactions.Count(IsMatched),
                AmbiguousCount = reconciliation.Transactions.Count(item => item.MatchStatus == AmbiguousStatus),
                UnmatchedCount = reconciliation.Transactions.Count(item => item.MatchStatus == UnmatchedStatus),
                Transactions = reconciliation.Transactions
                    .OrderBy(item => item.TransactionDate)
                    .ThenBy(item => item.BankTransactionId)
                    .Select(MapTransaction)
                    .ToList()
            };
        }

        private static BankTransactionResultDto MapTransaction(BankTransaction transaction)
        {
            return new BankTransactionResultDto
            {
                BankTransactionId = transaction.BankTransactionId,
                TransactionDate = transaction.TransactionDate,
                Amount = transaction.Amount,
                ReferenceNo = transaction.ReferenceNo,
                Description = transaction.Description,
                MatchStatus = transaction.MatchStatus,
                MatchedJournalEntryId = transaction.MatchedJournalEntryId,
                Candidates = transaction.Candidates
                    .OrderByDescending(item => item.Score)
                    .ThenBy(item => item.JournalEntryId)
                    .Select(item => new BankReconciliationCandidateDto
                    {
                        JournalEntryId = item.JournalEntryId,
                        Score = item.Score,
                        IsSelected = item.IsSelected
                    })
                    .ToList()
            };
        }
    }
}
