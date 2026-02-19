using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class HealthTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public HealthTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task LiveHealth_ReturnsOk()
    {
        var response = await _client.GetAsync("/health/live");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task ReadyHealth_ReturnsOk()
    {
        var response = await _client.GetAsync("/health/ready");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
