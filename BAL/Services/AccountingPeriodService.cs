using BAL.IServices;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;
using BAL.Shared;

namespace BAL.Services
{
    internal class AccountingPeriodService : IAccountingPeriodService
    {
        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;
        private readonly ILedgerBalanceService _ledgerBalanceService;

        public AccountingPeriodService(
            DataContext context,
            IAuditLogService auditLogService,
            ILedgerBalanceService ledgerBalanceService)
        {
            _context = context;
            _auditLogService = auditLogService;
            _ledgerBalanceService = ledgerBalanceService;
        }

        public async Task<List<AccountingPeriodResponseDto>> GetPeriodsAsync()
        {
            var periods = await _context.AccountingPeriods
                .AsNoTracking()
                .OrderByDescending(x => x.PeriodId)
                .ToListAsync();

            return periods.Select(MapToDto).ToList();
        }

        public async Task<AccountingPeriodResponseDto> CreateAsync(CreateAccountingPeriodRequestDto request, Guid actorUserId, string? ipAddress)
        {
            var start = request.StartDate.Date;
            var end = request.EndDate.Date;
            if (start > end)
            {
                throw new InvalidOperationException("StartDate cannot be greater than EndDate.");
            }

            var exists = await _context.AccountingPeriods.AnyAsync(x => x.PeriodId == request.PeriodId);
            if (exists)
            {
                throw new InvalidOperationException($"PeriodId {request.PeriodId} already exists.");
            }

            var overlapping = await _context.AccountingPeriods
                .AnyAsync(x => x.StartDate <= end && x.EndDate >= start);
            if (overlapping)
            {
                throw new InvalidOperationException("The period overlaps an existing accounting period.");
            }

            var entity = new AccountingPeriod
            {
                PeriodId = request.PeriodId,
                StartDate = start,
                EndDate = end,
                IsClosed = false
            };

            await _context.AccountingPeriods.AddAsync(entity);
            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "CREATE_PERIOD",
                "AccountingPeriods",
                entity.PeriodId.ToString(),
                ipAddress,
                new { entity.StartDate, entity.EndDate });

            return MapToDto(entity);
        }

        public async Task<bool> CloseAsync(int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await _context.AccountingPeriods
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.PeriodId == periodId);
            if (period == null || period.IsClosed)
            {
                return false;
            }

            await CloseAsync(
                periodId,
                new CloseAccountingPeriodRequestDto
                {
                    RequestId = Guid.NewGuid(),
                    ExpectedVersion = period.Version
                },
                actorUserId,
                ipAddress);
            return true;
        }

        public async Task<PeriodClosePreviewDto> PreviewCloseAsync(
            int periodId,
            CancellationToken cancellationToken = default)
        {
            var period = await _context.AccountingPeriods
                .AsNoTracking()
                .FirstOrDefaultAsync(item => item.PeriodId == periodId, cancellationToken)
                ?? throw new KeyNotFoundException("Accounting period was not found.");

            var entries = await _context.JournalEntries
                .AsNoTracking()
                .Where(item => item.EntryDate >= period.StartDate && item.EntryDate <= period.EndDate)
                .Select(item => new
                {
                    item.Status,
                    Lines = item.Lines.Select(line => new { line.Debit, line.Credit }).ToList()
                })
                .ToListAsync(cancellationToken);

            var draftCount = entries.Count(item =>
                string.Equals(item.Status, "Draft", StringComparison.OrdinalIgnoreCase));
            var postedEntries = entries
                .Where(item => string.Equals(item.Status, "Posted", StringComparison.OrdinalIgnoreCase))
                .ToList();
            var unbalancedCount = postedEntries.Count(item =>
            {
                var debit = decimal.Round(item.Lines.Sum(line => line.Debit), 2);
                var credit = decimal.Round(item.Lines.Sum(line => line.Credit), 2);
                return debit <= 0m || debit != credit;
            });

            var blockers = new List<string>();
            if (period.IsClosed)
            {
                blockers.Add("PERIOD_CLOSED");
            }
            if (draftCount > 0)
            {
                blockers.Add("DRAFT_ENTRIES");
            }
            if (unbalancedCount > 0)
            {
                blockers.Add("UNBALANCED_POSTED_ENTRIES");
            }

            return new PeriodClosePreviewDto
            {
                PeriodId = period.PeriodId,
                Version = period.Version,
                CanClose = blockers.Count == 0,
                DraftEntryCount = draftCount,
                PostedEntryCount = postedEntries.Count,
                UnbalancedPostedEntryCount = unbalancedCount,
                Blockers = blockers
            };
        }

        public async Task<PeriodCloseResultDto> CloseAsync(
            int periodId,
            CloseAccountingPeriodRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default)
        {
            var period = await _context.AccountingPeriods
                .FirstOrDefaultAsync(item => item.PeriodId == periodId, cancellationToken)
                ?? throw new KeyNotFoundException("Accounting period was not found.");

            if (period.IsClosed)
            {
                if (period.CloseRequestId == request.RequestId &&
                    period.ClosedAt.HasValue &&
                    period.ClosedByUserId.HasValue)
                {
                    return MapCloseResult(period, request.RequestId, replayed: true);
                }

                throw new ResourceConflictException("Accounting period is already closed.");
            }

            if (period.Version != request.ExpectedVersion)
            {
                throw new ResourceConflictException(
                    $"Accounting period version {period.Version} does not match expected version {request.ExpectedVersion}.");
            }

            var preview = await PreviewCloseAsync(periodId, cancellationToken);
            if (!preview.CanClose)
            {
                throw new InvalidOperationException(
                    $"Accounting period cannot be closed: {string.Join(", ", preview.Blockers)}.");
            }

            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                await _ledgerBalanceService.RefreshForPeriodAsync(periodId, cancellationToken);

                period.IsClosed = true;
                period.ClosedAt = DateTime.UtcNow;
                period.ClosedByUserId = actorUserId;
                period.CloseRequestId = request.RequestId;
                period.Version++;
                await _context.SaveChangesAsync(cancellationToken);

                await _auditLogService.WriteAsync(
                    actorUserId,
                    "CLOSE_PERIOD",
                    "AccountingPeriods",
                    periodId.ToString(),
                    ipAddress,
                    new { request.RequestId, period.Version });

                await transaction.CommitAsync(cancellationToken);
                return MapCloseResult(period, request.RequestId, replayed: false);
            }
            catch (DbUpdateConcurrencyException ex)
            {
                await transaction.RollbackAsync(cancellationToken);
                throw new ResourceConflictException($"Accounting period was changed by another request: {ex.Message}");
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        }

        private static AccountingPeriodResponseDto MapToDto(AccountingPeriod period)
        {
            return new AccountingPeriodResponseDto
            {
                PeriodId = period.PeriodId,
                StartDate = period.StartDate,
                EndDate = period.EndDate,
                IsClosed = period.IsClosed,
                ClosedAt = period.ClosedAt,
                ClosedByUserId = period.ClosedByUserId
            };
        }

        private static PeriodCloseResultDto MapCloseResult(
            AccountingPeriod period,
            Guid requestId,
            bool replayed)
        {
            return new PeriodCloseResultDto
            {
                PeriodId = period.PeriodId,
                Version = period.Version,
                ClosedAt = period.ClosedAt!.Value,
                ClosedByUserId = period.ClosedByUserId!.Value,
                RequestId = requestId,
                Replayed = replayed
            };
        }
    }
}
