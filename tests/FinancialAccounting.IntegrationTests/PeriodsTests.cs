using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class PeriodsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public PeriodsTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task GetPeriods_WithAuth_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync("/periods");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task CreatePeriod_InvalidDateRange_ReturnsBadRequest()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.PostAsJsonAsync("/periods", new
        {
            periodId = 209901,
            startDate = "2099-12-31",
            endDate = "2099-01-01"
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task ClosePeriod_AsFinanceManager_AllowsOrNotFound()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var response = await _client.PostAsync($"/periods/{TestDataFixture.ClosedPeriodId}/close", content: null);
        response.StatusCode.Should().BeOneOf(HttpStatusCode.NoContent, HttpStatusCode.NotFound);
    }
}
