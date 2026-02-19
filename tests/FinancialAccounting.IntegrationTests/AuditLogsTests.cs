using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class AuditLogsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public AuditLogsTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task AuditLogs_Admin_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.GetAsync("/audit-logs?page=1&pageSize=10");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task AuditLogs_Auditor_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var response = await _client.GetAsync("/audit-logs?page=1&pageSize=10");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task AuditLogs_User_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync("/audit-logs?page=1&pageSize=10");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
