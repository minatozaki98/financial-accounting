using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("periods")]
    [Authorize]
    public class PeriodsController : ControllerBase
    {
        private readonly IAccountingPeriodService _accountingPeriodService;

        public PeriodsController(IAccountingPeriodService accountingPeriodService)
        {
            _accountingPeriodService = accountingPeriodService;
        }

        [HttpGet]
        public async Task<IActionResult> GetPeriods()
        {
            var result = await _accountingPeriodService.GetPeriodsAsync();
            return Ok(result);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateAccountingPeriodRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _accountingPeriodService.CreateAsync(request, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
            return CreatedAtAction(nameof(GetPeriods), new { periodId = result.PeriodId }, result);
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{periodId:int}/close")]
        public async Task<IActionResult> Close([FromRoute] int periodId)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var closed = await _accountingPeriodService.CloseAsync(periodId, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
            if (!closed)
            {
                return Problem(
                    statusCode: StatusCodes.Status404NotFound,
                    title: "Period not found",
                    detail: "Period was not found or is already closed.");
            }

            return NoContent();
        }
    }
}
