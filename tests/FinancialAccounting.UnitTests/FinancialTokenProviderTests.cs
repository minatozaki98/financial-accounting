using BAL.Shared;
using FluentAssertions;
using Microsoft.Extensions.Options;
using MODEL.ApplicationConfig;
using MODEL.Entities;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class FinancialTokenProviderTests
{
    [Fact]
    public void CreateAccessToken_ContainsExpectedClaims()
    {
        var settings = new AppSettings
        {
            JwtSecret = "this-is-a-long-enough-test-secret-for-hmac-512-signing-key-0123456789abcdef",
            JwtIssuer = "issuer",
            JwtAudience = "audience",
            AccessTokenMinutes = 60
        };

        var provider = new FinancialTokenProvider(Options.Create(settings));
        var user = new Users
        {
            UserId = Guid.NewGuid(),
            Username = "admin",
            Email = "admin@local.invalid",
            PasswordHash = new byte[] { 1 },
            PasswordSalt = new byte[] { 2 },
            FullName = "admin",
            PhoneNumber = string.Empty
        };

        var (token, expiresAt) = provider.CreateAccessToken(user, new[] { "Admin", "User" });

        token.Should().NotBeNullOrWhiteSpace();
        expiresAt.Should().BeAfter(DateTime.UtcNow);

        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
        jwt.Issuer.Should().Be("issuer");
        jwt.Audiences.Should().Contain("audience");
        jwt.Claims.Should().Contain(c => c.Type.EndsWith("nameidentifier", StringComparison.OrdinalIgnoreCase) && c.Value == user.UserId.ToString());
        jwt.Claims.Should().Contain(c => c.Type == ClaimTypes.Email && c.Value == user.Email);
        jwt.Claims.Count(c => c.Type.EndsWith("role", StringComparison.OrdinalIgnoreCase)).Should().Be(2);
    }
}
