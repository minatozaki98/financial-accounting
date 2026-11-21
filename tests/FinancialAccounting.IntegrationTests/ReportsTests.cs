using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class ReportsTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

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
    public async Task TrialBalance_Admin_PersistsItsReportAndAuditRecord()
    {
        long reportId;
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        var auditCountBefore = 0;
        await using (var scope = _factory.Services.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<DataContext>();
            auditCountBefore = await context.AuditLogs.CountAsync();
        }

        var response = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        await using (var scope = _factory.Services.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<DataContext>();
            var report = await context.Reports
                .OrderByDescending(x => x.ReportId)
                .FirstAsync();

            report.ReportType.Should().Be("TrialBalance");
            report.PeriodId.Should().Be(TestDataFixture.OpenPeriodId);
            reportId = report.ReportId;

            (await context.AuditLogs.CountAsync()).Should().Be(auditCountBefore + 1);
            (await context.AuditLogs.AnyAsync(x =>
                x.Action == "GENERATE_REPORT" &&
                x.EntityName == "Reports" &&
                x.EntityId == reportId.ToString())).Should().BeTrue();
        }
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
