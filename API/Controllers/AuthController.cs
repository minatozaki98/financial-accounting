using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.DTOs;

namespace API.Controllers
{
    [ApiController]
    [Route("auth")]
    public class AuthController : ControllerBase
    {
        private readonly IFinancialAuthService _financialAuthService;

        public AuthController(IFinancialAuthService financialAuthService)
        {
            _financialAuthService = financialAuthService;
        }

        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] FinancialLoginRequestDto request)
        {
            var result = await _financialAuthService.LoginAsync(request, HttpContext.Connection.RemoteIpAddress?.ToString());
            if (result == null)
            {
                return Unauthorized(new { message = "Invalid username or password." });
            }

            return Ok(result);
        }
    }
}
