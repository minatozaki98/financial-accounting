using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class JournalEntriesTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public JournalEntriesTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task GetPaged_WithAuth_ReturnsPagedShape()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync("/journal-entries?page=1&pageSize=20");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task CreateDraft_WithInvalidLineShape_ReturnsBadRequest()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.PostAsJsonAsync("/journal-entries", new
        {
            entryDate = "2026-03-01",
            description = "Invalid",
            referenceNo = "INV-1",
            lines = new[]
            {
                new { accountId = TestDataFixture.AssetAccountId, debit = 100, credit = 100 }
            }
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task CreateDraft_AsAuditor_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var response = await _client.PostAsJsonAsync("/journal-entries", new
        {
            entryDate = "2026-03-01",
            lines = new[]
            {
                new { accountId = TestDataFixture.AssetAccountId, debit = 100, credit = 0 },
                new { accountId = TestDataFixture.LiabilityAccountId, debit = 0, credit = 100 }
            }
        });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task ReversePosted_AsAdmin_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.PostAsync($"/journal-entries/{TestDataFixture.PostedEntryId}/reverse", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
