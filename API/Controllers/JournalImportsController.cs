using API.Helpers;
using API.Models;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers
{
    [ApiController]
    [Route("journal-imports")]
    [Authorize(Roles = "Admin,FinanceManager")]
    public sealed class JournalImportsController : ControllerBase
    {
        private const long MaximumFileSize = 5 * 1024 * 1024;
        private readonly IJournalImportService _journalImportService;

        public JournalImportsController(IJournalImportService journalImportService)
        {
            _journalImportService = journalImportService;
        }

        [HttpPost("validate")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> Validate(
            [FromForm] JournalImportUploadForm form,
            CancellationToken cancellationToken = default)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }
            if (form.File == null || form.File.Length == 0)
            {
                return ValidationProblem("A non-empty CSV file is required.");
            }
            if (form.File.Length > MaximumFileSize)
            {
                return ValidationProblem($"CSV file cannot exceed {MaximumFileSize} bytes.");
            }
            if (form.IdempotencyKey.Length is < 8 or > 100)
            {
                return ValidationProblem("Idempotency key must contain 8 to 100 characters.");
            }

            await using var stream = form.File.OpenReadStream();
            var result = await _journalImportService.ValidateCsvAsync(
                stream,
                form.File.FileName,
                form.IdempotencyKey,
                form.Atomic,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return Ok(result);
        }

        [HttpPost("{importId:guid}/commit")]
        public async Task<IActionResult> Commit(
            [FromRoute] Guid importId,
            CancellationToken cancellationToken)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _journalImportService.CommitAsync(
                importId,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return Ok(result);
        }
    }
}
