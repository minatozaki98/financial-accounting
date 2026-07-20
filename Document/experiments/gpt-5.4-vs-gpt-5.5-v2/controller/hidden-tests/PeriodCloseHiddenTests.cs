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

namespace FinancialAccounting.BenchmarkHiddenTests;

public sealed class PeriodCloseHiddenTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public PeriodCloseHiddenTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task Close_WithUnbalancedPostedEntry_ReturnsBadRequestWithoutPartialState()
    {
        const int periodId = 209901;
        SeedPeriod(periodId, balanced: false);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        var response = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = Guid.NewGuid(),
            expectedVersion = 1
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var period = context.AccountingPeriods.Single(item => item.PeriodId == periodId);
        period.IsClosed.Should().BeFalse();
        period.CloseRequestId.Should().BeNull();
        context.LedgerBalances.Count(item => item.PeriodId == periodId).Should().Be(0);
        context.AuditLogs.Count(item => item.Action == "CLOSE_PERIOD" && item.EntityId == periodId.ToString())
            .Should()
            .Be(0);
    }

    [Fact]
    public async Task Close_WithSameRequestReplaysAndDifferentRequestConflicts()
    {
        const int periodId = 209902;
        SeedPeriod(periodId, balanced: true);
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var firstRequestId = Guid.NewGuid();

        var firstResponse = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = firstRequestId,
            expectedVersion = 1
        });

        firstResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var first = JsonDocument.Parse(await firstResponse.Content.ReadAsStringAsync());
        first.RootElement.GetProperty("version").GetInt32().Should().Be(2);
        first.RootElement.GetProperty("replayed").GetBoolean().Should().BeFalse();

        var replayResponse = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = firstRequestId,
            expectedVersion = 1
        });

        replayResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayResponse.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();

        var conflictResponse = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = Guid.NewGuid(),
            expectedVersion = 1
        });

        conflictResponse.StatusCode.Should().Be(HttpStatusCode.Conflict);

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var period = context.AccountingPeriods.Single(item => item.PeriodId == periodId);
        period.CloseRequestId.Should().Be(firstRequestId);
        period.Version.Should().Be(2);
        context.AuditLogs.Count(item => item.Action == "CLOSE_PERIOD" && item.EntityId == periodId.ToString())
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task Close_WithStaleVersionOnOpenPeriod_ReturnsConflictAndKeepsVersion()
    {
        const int periodId = 209903;
        SeedPeriod(periodId, balanced: true);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        var response = await _client.PostAsJsonAsync($"/periods/{periodId}/close", new
        {
            requestId = Guid.NewGuid(),
            expectedVersion = 2
        });

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var period = context.AccountingPeriods.Single(item => item.PeriodId == periodId);
        period.Version.Should().Be(1);
        period.IsClosed.Should().BeFalse();
    }

    private void SeedPeriod(int periodId, bool balanced)
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        if (context.AccountingPeriods.Any(item => item.PeriodId == periodId))
        {
            return;
        }

        var adminId = context.Users.Single(item => item.Username == TestDataFixture.AdminUsername).UserId;
        var year = periodId / 100;
        var period = new AccountingPeriod
        {
            PeriodId = periodId,
            StartDate = new DateTime(year, 1, 1),
            EndDate = new DateTime(year, 12, 31),
            IsClosed = false,
            Version = 1
        };
        var entry = new JournalEntry
        {
            EntryDate = period.StartDate.AddDays(4),
            Description = $"Hidden close {periodId}",
            ReferenceNo = $"HIDDEN-CLOSE-{periodId}",
            Status = "Posted",
            CreatedByUserId = adminId,
            CreatedAt = DateTime.UtcNow,
            PostedAt = DateTime.UtcNow
        };
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.AssetAccountId,
            Debit = 125m,
            Credit = 0m,
            LineDescription = "Hidden debit"
        });
        if (balanced)
        {
            entry.Lines.Add(new JournalEntryLine
            {
                AccountId = TestDataFixture.LiabilityAccountId,
                Debit = 0m,
                Credit = 125m,
                LineDescription = "Hidden credit"
            });
        }

        context.AccountingPeriods.Add(period);
        context.JournalEntries.Add(entry);
        context.SaveChanges();
    }
}
