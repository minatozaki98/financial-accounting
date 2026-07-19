using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class ReportsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;
    private readonly TestApiFactory _factory;

    public ReportsTests(TestApiFactory factory)
    {
        _factory = factory;
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

    [Fact]
    public async Task TrialBalance_RepeatedCalls_StillPersistReportAndAuditRows()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var before = CountReportAndAuditRows();

        var first = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");
        var second = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");

        first.StatusCode.Should().Be(HttpStatusCode.OK);
        second.StatusCode.Should().Be(HttpStatusCode.OK);

        var after = CountReportAndAuditRows();
        after.ReportCount.Should().Be(before.ReportCount + 2);
        after.GenerateReportAuditCount.Should().Be(before.GenerateReportAuditCount + 2);
    }

    private (int ReportCount, int GenerateReportAuditCount) CountReportAndAuditRows()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        return (
            context.Reports.Count(),
            context.AuditLogs.Count(x => x.Action == "GENERATE_REPORT"));
    }
}
