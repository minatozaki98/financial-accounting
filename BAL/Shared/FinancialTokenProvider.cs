using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MODEL.ApplicationConfig;
using MODEL.Entities;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace BAL.Shared
{
    public sealed class FinancialTokenProvider
    {
        private readonly AppSettings _appSettings;
        private readonly SymmetricSecurityKey _signingKey;

        public FinancialTokenProvider(IOptions<AppSettings> options)
        {
            _appSettings = options.Value;
            _signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_appSettings.JwtSecret));
        }

        public (string Token, DateTime ExpiresAtUtc) CreateAccessToken(Users user, IEnumerable<string> roles)
        {
            var now = DateTime.UtcNow;
            var expiresAt = now.AddMinutes(_appSettings.AccessTokenMinutes > 0 ? _appSettings.AccessTokenMinutes : 60);

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
                new Claim(ClaimTypes.Name, string.IsNullOrWhiteSpace(user.Username) ? user.Email : user.Username),
                new Claim(ClaimTypes.Email, user.Email)
            };

            foreach (var role in roles.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            var token = new JwtSecurityToken(
                issuer: _appSettings.JwtIssuer,
                audience: _appSettings.JwtAudience,
                claims: claims,
                notBefore: now,
                expires: expiresAt,
                signingCredentials: new SigningCredentials(_signingKey, SecurityAlgorithms.HmacSha512Signature));

            return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
        }

    }
}
