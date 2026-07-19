using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class AccountsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public AccountsTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task GetAccounts_WithAuth_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync("/accounts");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task GetAccountById_NotFound_Returns404()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync("/accounts/999999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CreateAccount_Admin_Created_AndDuplicateRejected()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var code = $"T{DateTime.UtcNow:HHmmss}";

        var create = await _client.PostAsJsonAsync("/accounts", new
        {
            accountCode = code,
            accountName = "Test Account",
            accountType = "Asset",
            isActive = true
        });

        create.StatusCode.Should().Be(HttpStatusCode.Created);

        var duplicate = await _client.PostAsJsonAsync("/accounts", new
        {
            accountCode = code,
            accountName = "Test Account Duplicate",
            accountType = "Asset",
            isActive = true
        });

        duplicate.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var body = await duplicate.Content.ReadFromJsonAsync<JsonElement>();
        body.TryGetProperty("title", out _).Should().BeTrue();
    }

    [Fact]
    public async Task GetAccounts_AfterCreate_ReturnsNewAccountFromRefreshedCache()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var code = $"C{DateTime.UtcNow:HHmmssfff}";

        var before = await _client.GetAsync("/accounts");
        before.StatusCode.Should().Be(HttpStatusCode.OK);

        var create = await _client.PostAsJsonAsync("/accounts", new
        {
            accountCode = code,
            accountName = "Cached Account",
            accountType = "Asset",
            isActive = true
        });
        create.StatusCode.Should().Be(HttpStatusCode.Created);

        var after = await _client.GetAsync("/accounts");
        after.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await after.Content.ReadFromJsonAsync<JsonElement>();
        body.EnumerateArray().Should().Contain(x => x.GetProperty("accountCode").GetString() == code);
    }

    [Fact]
    public async Task CreateAccount_NonAdmin_Forbidden()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var response = await _client.PostAsJsonAsync("/accounts", new
        {
            accountCode = "FORBID-01",
            accountName = "Forbidden",
            accountType = "Asset",
            isActive = true
        });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
