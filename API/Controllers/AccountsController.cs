using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("accounts")]
    [Authorize]
    public class AccountsController : ControllerBase
    {
        private readonly IChartOfAccountsService _chartOfAccountsService;

        public AccountsController(IChartOfAccountsService chartOfAccountsService)
        {
            _chartOfAccountsService = chartOfAccountsService;
        }

        [HttpGet]
        public async Task<IActionResult> GetAccounts([FromQuery] string? type, [FromQuery] bool? isActive, [FromQuery] string? search)
        {
            var result = await _chartOfAccountsService.GetAccountsAsync(type, isActive, search);
            return Ok(result);
        }

        [HttpGet("{accountId:int}")]
        public async Task<IActionResult> GetById([FromRoute] int accountId)
        {
            var result = await _chartOfAccountsService.GetByIdAsync(accountId);
            if (result == null)
            {
                return NotFound(new { message = "Account was not found." });
            }

            return Ok(result);
        }

        [HttpGet("{accountId:int}/balance")]
        public async Task<IActionResult> GetBalance([FromRoute] int accountId)
        {
            var result = await _chartOfAccountsService.GetBalanceAsync(accountId);
            if (result == null)
            {
                return NotFound(new { message = "Account was not found." });
            }

            return Ok(result);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateAccountRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _chartOfAccountsService.CreateAsync(request, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return CreatedAtAction(nameof(GetById), new { accountId = result.AccountId }, result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpPut("{accountId:int}")]
        public async Task<IActionResult> Update([FromRoute] int accountId, [FromBody] UpdateAccountRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var updated = await _chartOfAccountsService.UpdateAsync(accountId, request, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                if (!updated)
                {
                    return NotFound(new { message = "Account was not found." });
                }

                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
