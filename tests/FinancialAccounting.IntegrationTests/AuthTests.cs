using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class AuthTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public AuthTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Login_WithValidCredentials_ReturnsTokenShape()
    {
        var response = await _client.PostAsJsonAsync("/auth/login", new
        {
            username = TestDataFixture.AdminUsername,
            password = TestDataFixture.DefaultPassword
        });

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        body.TryGetProperty("accessToken", out _).Should().BeTrue();
        body.TryGetProperty("accessTokenExpiresAtUtc", out _).Should().BeTrue();
        body.TryGetProperty("roles", out _).Should().BeTrue();
    }

    [Fact]
    public async Task Login_WithInvalidCredentials_ReturnsUnauthorized()
    {
        var response = await _client.PostAsJsonAsync("/auth/login", new
        {
            username = TestDataFixture.AdminUsername,
            password = "wrong-password"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Login_WithMissingFields_ReturnsBadRequest()
    {
        var response = await _client.PostAsJsonAsync("/auth/login", new { });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
