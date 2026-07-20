using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using MODEL.Entities;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class PeriodsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;
    private readonly TestApiFactory _factory;

    public PeriodsTests(TestApiFactory factory)
    {
        _factory = factory;
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

    [Fact]
    public async Task ClosePreview_WithDraftEntries_ReturnsExplicitBlocker()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());

        var response = await _client.GetAsync($"/periods/{TestDataFixture.OpenPeriodId}/close-preview");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        using var payload = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        payload.RootElement.GetProperty("canClose").GetBoolean().Should().BeFalse();
        payload.RootElement.GetProperty("draftEntryCount").GetInt32().Should().BeGreaterThan(0);
        payload.RootElement.GetProperty("blockers")
            .EnumerateArray()
            .Select(item => item.GetString())
            .Should()
            .Contain("DRAFT_ENTRIES");
    }

    [Fact]
    public async Task Close_WithValidPreview_ClosesAtomicallyAndReplaysIdempotently()
    {
        const int periodId = 209801;
        SeedClosablePeriod(periodId);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        var previewResponse = await _client.GetAsync($"/periods/{periodId}/close-preview");
        previewResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var preview = JsonDocument.Parse(await previewResponse.Content.ReadAsStringAsync());
        var version = preview.RootElement.GetProperty("version").GetInt32();
        var requestId = Guid.NewGuid();

        var closeResponse = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId,
            expectedVersion = version
        });

        closeResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var first = JsonDocument.Parse(await closeResponse.Content.ReadAsStringAsync());
        first.RootElement.GetProperty("replayed").GetBoolean().Should().BeFalse();
        first.RootElement.GetProperty("version").GetInt32().Should().Be(version + 1);

        var replayResponse = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId,
            expectedVersion = version
        });

        replayResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayResponse.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var period = context.AccountingPeriods.Single(item => item.PeriodId == periodId);
        period.IsClosed.Should().BeTrue();
        period.CloseRequestId.Should().Be(requestId);
        context.LedgerBalances.Any(item => item.PeriodId == periodId).Should().BeTrue();
        context.AuditLogs.Count(item => item.Action == "CLOSE_PERIOD" && item.EntityId == periodId.ToString())
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task Close_WithStaleVersion_ReturnsConflict()
    {
        const int periodId = 209802;
        SeedClosablePeriod(periodId);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        var response = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = Guid.NewGuid(),
            expectedVersion = 99
        });

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    private void SeedClosablePeriod(int periodId)
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        if (context.AccountingPeriods.Any(item => item.PeriodId == periodId))
        {
            return;
        }

        var adminId = context.Users.Single(item => item.Username == TestDataFixture.AdminUsername).UserId;
        var period = new AccountingPeriod
        {
            PeriodId = periodId,
            StartDate = new DateTime(periodId / 100, 1, 1),
            EndDate = new DateTime(periodId / 100, 12, 31),
            IsClosed = false
        };
        var entry = new JournalEntry
        {
            EntryDate = period.StartDate.AddDays(10),
            Description = "Period close reference",
            ReferenceNo = $"CLOSE-{periodId}",
            Status = "Posted",
            CreatedByUserId = adminId,
            PostedAt = DateTime.UtcNow
        };
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.AssetAccountId,
            Debit = 125m
        });
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.LiabilityAccountId,
            Credit = 125m
        });

        context.AccountingPeriods.Add(period);
        context.JournalEntries.Add(entry);
        context.SaveChanges();
    }
}
