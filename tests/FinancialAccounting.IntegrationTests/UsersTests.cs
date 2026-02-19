using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class UsersTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public UsersTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task GetMe_WithoutToken_ReturnsUnauthorized()
    {
        _client.ClearAuth();
        var response = await _client.GetAsync("/users/me");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetMe_WithToken_ReturnsCurrentUser()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.GetAsync("/users/me");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        body.TryGetProperty("userId", out _).Should().BeTrue();
        body.TryGetProperty("username", out _).Should().BeTrue();
        body.TryGetProperty("roles", out _).Should().BeTrue();
    }

    [Fact]
    public async Task CreateUser_AsAdmin_ReturnsCreated()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.PostAsJsonAsync("/users", new
        {
            username = $"test-user-{Guid.NewGuid():N}"[..16],
            email = $"user-{Guid.NewGuid():N}@local.invalid",
            password = "User@12345!",
            role = "User"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }

    [Fact]
    public async Task CreateUser_AsNonAdmin_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.PostAsJsonAsync("/users", new
        {
            username = "blocked-user",
            email = "blocked@local.invalid",
            password = "User@12345!",
            role = "User"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
