using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers
{
    [ApiController]
    [Route("reports")]
    [Authorize(Roles = "Admin,FinanceManager,Auditor")]
    public class ReportsController : ControllerBase
    {
        private readonly IFinancialReportService _financialReportService;

        public ReportsController(IFinancialReportService financialReportService)
        {
            _financialReportService = financialReportService;
        }

        [HttpGet("trial-balance")]
        public async Task<IActionResult> GetTrialBalance([FromQuery] int periodId)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _financialReportService.GetTrialBalanceAsync(periodId, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("profit-loss")]
        public async Task<IActionResult> GetProfitLoss([FromQuery] int periodId)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _financialReportService.GetProfitLossAsync(periodId, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("balance-sheet")]
        public async Task<IActionResult> GetBalanceSheet([FromQuery] int periodId)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _financialReportService.GetBalanceSheetAsync(periodId, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("account-ledger")]
        public async Task<IActionResult> GetAccountLedger([FromQuery] int accountId, [FromQuery] int periodId)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var result = await _financialReportService.GetAccountLedgerAsync(accountId, periodId, actorId.Value, HttpContext.Connection.RemoteIpAddress?.ToString());
                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
