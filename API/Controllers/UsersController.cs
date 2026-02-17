using API.Helpers;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("users")]
    [Authorize]
    public class UsersController : ControllerBase
    {
        private readonly IFinancialAuthService _financialAuthService;

        public UsersController(IFinancialAuthService financialAuthService)
        {
            _financialAuthService = financialAuthService;
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMe()
        {
            var userId = UserClaimsHelper.GetUserId(User);
            if (!userId.HasValue)
            {
                return Unauthorized();
            }

            var result = await _financialAuthService.GetCurrentUserAsync(userId.Value);
            if (result == null)
            {
                return NotFound(new { message = "User was not found." });
            }

            return Ok(result);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateUserRequestDto request)
        {
            var actorId = UserClaimsHelper.GetUserId(User);
            if (!actorId.HasValue)
            {
                return Unauthorized();
            }

            try
            {
                var created = await _financialAuthService.CreateUserAsync(
                    request,
                    actorId.Value,
                    HttpContext.Connection.RemoteIpAddress?.ToString());
                return StatusCode(StatusCodes.Status201Created, created);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
