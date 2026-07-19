using BAL.IServices;
using BAL.Shared;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;

namespace BAL.Services
{
    internal class AccountingPeriodService : IAccountingPeriodService
    {
        private readonly DataContext _context;
        private readonly IAuditLogService _auditLogService;
        private readonly FinancialReadCache _cache;

        public AccountingPeriodService(DataContext context, IAuditLogService auditLogService, FinancialReadCache cache)
        {
            _context = context;
            _auditLogService = auditLogService;
            _cache = cache;
        }

        public async Task<List<AccountingPeriodResponseDto>> GetPeriodsAsync()
        {
            var periods = await _cache.GetOrCreatePeriodsAsync(GetPeriodsUncachedAsync);
            return periods.Select(ClonePeriod).ToList();
        }

        private async Task<List<AccountingPeriodResponseDto>> GetPeriodsUncachedAsync()
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
            _cache.InvalidatePeriods();

            return MapToDto(entity);
        }

        public async Task<bool> CloseAsync(int periodId, Guid actorUserId, string? ipAddress)
        {
            var period = await _context.AccountingPeriods.FirstOrDefaultAsync(x => x.PeriodId == periodId);
            if (period == null || period.IsClosed)
            {
                return false;
            }

            period.IsClosed = true;
            period.ClosedAt = DateTime.UtcNow;
            period.ClosedByUserId = actorUserId;

            await _context.SaveChangesAsync();

            await _auditLogService.WriteAsync(
                actorUserId,
                "CLOSE_PERIOD",
                "AccountingPeriods",
                periodId.ToString(),
                ipAddress);
            _cache.InvalidatePeriods();

            return true;
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

        private static AccountingPeriodResponseDto ClonePeriod(AccountingPeriodResponseDto period)
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
    }
}
