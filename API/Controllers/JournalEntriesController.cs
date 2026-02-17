using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("journal-entries")]
    [Authorize]
    public class JournalEntriesController : ControllerBase
    {
        private readonly IJournalEntryService _journalEntryService;

        public JournalEntriesController(IJournalEntryService journalEntryService)
        {
            _journalEntryService = journalEntryService;
        }

        [Authorize(Roles = "Admin,User,FinanceManager")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateJournalEntryRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _journalEntryService.CreateDraftAsync(request, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return CreatedAtAction(nameof(GetById), new { id = result.JournalEntryId }, result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("bulk")]
        public async Task<IActionResult> BulkCreate([FromBody] BulkCreateJournalEntriesRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var createdIds = await _journalEntryService.BulkCreateDraftAsync(request, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(new { ids = createdIds });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("{id:long}")]
        public async Task<IActionResult> GetById([FromRoute] long id)
        {
            var result = await _journalEntryService.GetByIdAsync(id);
            if (result == null)
            {
                return NotFound(new { message = "Journal entry was not found." });
            }

            return Ok(result);
        }

        [HttpGet]
        public async Task<IActionResult> GetPaged(
            [FromQuery] DateTime? from,
            [FromQuery] DateTime? to,
            [FromQuery] string? status,
            [FromQuery] int? accountId,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? sort = "entryDate_desc")
        {
            var result = await _journalEntryService.GetPagedAsync(from, to, status, accountId, search, page, pageSize, sort);
            return Ok(result);
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{id:long}/post")]
        public async Task<IActionResult> Post([FromRoute] long id)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var posted = await _journalEntryService.PostAsync(id, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                if (!posted)
                {
                    return NotFound(new { message = "Draft journal entry was not found." });
                }

                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{id:long}/reverse")]
        public async Task<IActionResult> Reverse([FromRoute] long id)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var newId = await _journalEntryService.ReverseAsync(id, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(new { reversingEntryId = newId });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete("{id:long}")]
        public async Task<IActionResult> DeleteDraft([FromRoute] long id)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var deleted = await _journalEntryService.DeleteDraftAsync(id, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
            if (!deleted)
            {
                return NotFound(new { message = "Draft journal entry was not found." });
            }

            return NoContent();
        }
    }
}
