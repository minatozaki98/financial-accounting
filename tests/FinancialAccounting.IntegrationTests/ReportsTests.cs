using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class ReportsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public ReportsTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task TrialBalance_Admin_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Reports_User_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync($"/reports/profit-loss?periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Ledger_InvalidAccount_ReturnsBadRequest()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var response = await _client.GetAsync($"/reports/account-ledger?accountId=999999&periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
