using BAL.IServices;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.DTOs;
using MODEL.Entities;
using System.Text.Json;

namespace BAL.Services
{
    internal class AuditLogService : IAuditLogService
    {
        private readonly DataContext _context;

        public AuditLogService(DataContext context)
        {
            _context = context;
        }

        public async Task WriteAsync(Guid? userId, string action, string? entityName, string? entityId, string? ipAddress, object? details = null)
        {
            var model = new AuditLog
            {
                UserId = userId,
                Action = action,
                EntityName = entityName,
                EntityId = entityId,
                IpAddress = ipAddress,
                DetailsJson = details == null ? null : JsonSerializer.Serialize(details),
                Timestamp = DateTime.UtcNow
            };

            await _context.AuditLogs.AddAsync(model);
            await _context.SaveChangesAsync();
        }

        public async Task<PagedResultDto<AuditLogResponseDto>> GetPagedAsync(
            DateTime? from,
            DateTime? to,
            Guid? userId,
            string? action,
            int page,
            int pageSize)
        {
            page = page < 1 ? 1 : page;
            pageSize = pageSize < 1 ? 50 : pageSize;

            var query = _context.AuditLogs.AsNoTracking().AsQueryable();

            if (from.HasValue)
            {
                query = query.Where(x => x.Timestamp >= from.Value);
            }

            if (to.HasValue)
            {
                query = query.Where(x => x.Timestamp <= to.Value);
            }

            if (userId.HasValue)
            {
                query = query.Where(x => x.UserId == userId.Value);
            }

            if (!string.IsNullOrWhiteSpace(action))
            {
                query = query.Where(x => x.Action == action);
            }

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(x => x.Timestamp)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(x => new AuditLogResponseDto
                {
                    AuditLogId = x.AuditLogId,
                    UserId = x.UserId,
                    Action = x.Action,
                    EntityName = x.EntityName,
                    EntityId = x.EntityId,
                    Timestamp = x.Timestamp,
                    IpAddress = x.IpAddress,
                    DetailsJson = x.DetailsJson
                })
                .ToListAsync();

            return new PagedResultDto<AuditLogResponseDto>
            {
                Page = page,
                PageSize = pageSize,
                TotalCount = totalCount,
                Items = items
            };
        }
    }
}
