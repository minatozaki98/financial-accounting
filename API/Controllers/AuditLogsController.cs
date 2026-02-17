using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers
{
    [ApiController]
    [Route("audit-logs")]
    [Authorize(Roles = "Admin,Auditor")]
    public class AuditLogsController : ControllerBase
    {
        private readonly IAuditLogService _auditLogService;

        public AuditLogsController(IAuditLogService auditLogService)
        {
            _auditLogService = auditLogService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAuditLogs(
            [FromQuery] DateTime? from,
            [FromQuery] DateTime? to,
            [FromQuery] Guid? userId,
            [FromQuery] string? action,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 50)
        {
            var result = await _auditLogService.GetPagedAsync(from, to, userId, action, page, pageSize);
            return Ok(result);
        }
    }
}
