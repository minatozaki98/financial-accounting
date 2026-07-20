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

public class ReconciliationsTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public ReconciliationsTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task Reconciliation_ExactReference_AutoMatchesFinalizesAndReplays()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-01-01",
            dateTo = "2026-01-31",
            transactions = new[]
            {
                new
                {
                    transactionDate = "2026-01-15",
                    amount = 100m,
                    referenceNo = "SEED-POSTED",
                    description = "Statement deposit"
                }
            }
        });

        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();
        created.RootElement.GetProperty("version").GetInt32().Should().Be(1);

        var matchResponse = await _client.PostAsync(
            $"/reconciliations/{reconciliationId}/auto-match",
            null);

        matchResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var matched = JsonDocument.Parse(await matchResponse.Content.ReadAsStringAsync());
        matched.RootElement.GetProperty("matchedCount").GetInt32().Should().Be(1);
        matched.RootElement.GetProperty("ambiguousCount").GetInt32().Should().Be(0);
        matched.RootElement.GetProperty("unmatchedCount").GetInt32().Should().Be(0);
        var version = matched.RootElement.GetProperty("version").GetInt32();

        var exceptionsResponse = await _client.GetAsync(
            $"/reconciliations/{reconciliationId}/exceptions");
        exceptionsResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var exceptions = JsonDocument.Parse(await exceptionsResponse.Content.ReadAsStringAsync());
        exceptions.RootElement.GetProperty("items").GetArrayLength().Should().Be(0);

        var requestId = Guid.NewGuid();
        var finalizeResponse = await _client.PostAsJsonAsync(
            $"/reconciliations/{reconciliationId}/finalize",
            new
            {
                requestId,
                expectedVersion = version
            });

        finalizeResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var finalized = JsonDocument.Parse(await finalizeResponse.Content.ReadAsStringAsync());
        finalized.RootElement.GetProperty("status").GetString().Should().Be("Finalized");
        finalized.RootElement.GetProperty("replayed").GetBoolean().Should().BeFalse();

        var replayResponse = await _client.PostAsJsonAsync(
            $"/reconciliations/{reconciliationId}/finalize",
            new
            {
                requestId,
                expectedVersion = version
            });
        replayResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayResponse.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        context.AuditLogs.Count(item =>
                item.Action == "FINALIZE_BANK_RECONCILIATION" &&
                item.EntityId == reconciliationId.ToString())
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task Reconciliation_AmbiguousCandidates_RequiresUniqueManualConfirmation()
    {
        var candidateIds = SeedAmbiguousJournalEntries();
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-05-01",
            dateTo = "2026-05-31",
            transactions = new[]
            {
                new { transactionDate = "2026-05-10", amount = 50m, description = "First statement row" },
                new { transactionDate = "2026-05-10", amount = 50m, description = "Second statement row" }
            }
        });
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();

        var matchResponse = await _client.PostAsync(
            $"/reconciliations/{reconciliationId}/auto-match",
            null);

        matchResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var matched = JsonDocument.Parse(await matchResponse.Content.ReadAsStringAsync());
        matched.RootElement.GetProperty("ambiguousCount").GetInt32().Should().Be(2);
        var version = matched.RootElement.GetProperty("version").GetInt32();
        var transactions = matched.RootElement.GetProperty("transactions")
            .EnumerateArray()
            .Select(item => item.GetProperty("bankTransactionId").GetInt64())
            .ToArray();

        var firstConfirmation = await _client.PostAsJsonAsync(
            $"/reconciliations/{reconciliationId}/confirm",
            new
            {
                bankTransactionId = transactions[0],
                journalEntryId = candidateIds[0],
                expectedVersion = version
            });

        firstConfirmation.StatusCode.Should().Be(HttpStatusCode.OK);
        using var confirmed = JsonDocument.Parse(await firstConfirmation.Content.ReadAsStringAsync());
        var nextVersion = confirmed.RootElement.GetProperty("version").GetInt32();

        var duplicateConfirmation = await _client.PostAsJsonAsync(
            $"/reconciliations/{reconciliationId}/confirm",
            new
            {
                bankTransactionId = transactions[1],
                journalEntryId = candidateIds[0],
                expectedVersion = nextVersion
            });

        duplicateConfirmation.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task Reconciliation_FinalizeWithStaleVersion_ReturnsConflict()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-06-01",
            dateTo = "2026-06-30",
            transactions = new[]
            {
                new { transactionDate = "2026-06-10", amount = 999m, description = "Unmatched" }
            }
        });
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();

        var response = await _client.PostAsJsonAsync(
            $"/reconciliations/{reconciliationId}/finalize",
            new
            {
                requestId = Guid.NewGuid(),
                expectedVersion = 99
            });

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    [Fact]
    public async Task Reconciliation_CreateAsAuditor_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());

        var response = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-01-01",
            dateTo = "2026-01-31",
            transactions = new[]
            {
                new { transactionDate = "2026-01-15", amount = 1m }
            }
        });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    private long[] SeedAmbiguousJournalEntries()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var existing = context.JournalEntries
            .Where(item => item.ReferenceNo != null && item.ReferenceNo.StartsWith("AMBIGUOUS-"))
            .Select(item => item.JournalEntryId)
            .ToArray();
        if (existing.Length >= 2)
        {
            return existing.Take(2).ToArray();
        }

        var adminId = context.Users.Single(item => item.Username == TestDataFixture.AdminUsername).UserId;
        var entries = new[]
        {
            CreatePostedEntry(adminId, "AMBIGUOUS-A"),
            CreatePostedEntry(adminId, "AMBIGUOUS-B")
        };
        context.JournalEntries.AddRange(entries);
        context.SaveChanges();
        return entries.Select(item => item.JournalEntryId).ToArray();
    }

    private static JournalEntry CreatePostedEntry(Guid actorId, string reference)
    {
        var entry = new JournalEntry
        {
            EntryDate = new DateTime(2026, 5, 10),
            Description = reference,
            ReferenceNo = reference,
            Status = "Posted",
            CreatedByUserId = actorId,
            PostedAt = DateTime.UtcNow
        };
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.AssetAccountId,
            Debit = 50m
        });
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.LiabilityAccountId,
            Credit = 50m
        });
        return entry;
    }
}
