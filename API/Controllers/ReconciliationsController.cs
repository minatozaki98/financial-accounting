using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("reconciliations")]
    [Authorize]
    public sealed class ReconciliationsController : ControllerBase
    {
        private readonly IBankReconciliationService _reconciliationService;

        public ReconciliationsController(IBankReconciliationService reconciliationService)
        {
            _reconciliationService = reconciliationService;
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost]
        public async Task<IActionResult> Create(
            [FromBody] CreateBankReconciliationRequestDto request,
            CancellationToken cancellationToken)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _reconciliationService.CreateAsync(
                request,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return CreatedAtAction(
                nameof(GetExceptions),
                new { reconciliationId = result.ReconciliationId },
                result);
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{reconciliationId:guid}/auto-match")]
        public async Task<IActionResult> AutoMatch(
            [FromRoute] Guid reconciliationId,
            CancellationToken cancellationToken)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _reconciliationService.AutoMatchAsync(
                reconciliationId,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return Ok(result);
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{reconciliationId:guid}/confirm")]
        public async Task<IActionResult> Confirm(
            [FromRoute] Guid reconciliationId,
            [FromBody] ConfirmBankReconciliationMatchRequestDto request,
            CancellationToken cancellationToken)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _reconciliationService.ConfirmAsync(
                reconciliationId,
                request,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return Ok(result);
        }

        [Authorize(Roles = "Admin,FinanceManager,Auditor")]
        [HttpGet("{reconciliationId:guid}/exceptions")]
        public async Task<IActionResult> GetExceptions(
            [FromRoute] Guid reconciliationId,
            CancellationToken cancellationToken)
        {
            var result = await _reconciliationService.GetExceptionsAsync(
                reconciliationId,
                cancellationToken);
            return Ok(result);
        }

        [Authorize(Roles = "Admin,FinanceManager")]
        [HttpPost("{reconciliationId:guid}/finalize")]
        public async Task<IActionResult> Finalize(
            [FromRoute] Guid reconciliationId,
            [FromBody] FinalizeBankReconciliationRequestDto request,
            CancellationToken cancellationToken)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _reconciliationService.FinalizeAsync(
                reconciliationId,
                request,
                actorId.Value,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
            return Ok(result);
        }
    }
}
