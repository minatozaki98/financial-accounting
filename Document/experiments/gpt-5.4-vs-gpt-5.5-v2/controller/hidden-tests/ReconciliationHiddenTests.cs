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

public sealed class ReconciliationHiddenTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public ReconciliationHiddenTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task AutoMatch_WithEqualScores_ReportsAmbiguousCandidatesInDeterministicOrder()
    {
        var candidates = SeedTieCandidates("HID-TIE-A", "HID-TIE-B", 42m);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-07-01",
            dateTo = "2026-07-31",
            transactions = new[]
            {
                new { transactionDate = "2026-07-10", amount = 42m, description = "Tie candidate row" }
            }
        });
        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();

        var matchResponse = await _client.PostAsync($"/reconciliations/{reconciliationId}/auto-match", null);

        matchResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var matched = JsonDocument.Parse(await matchResponse.Content.ReadAsStringAsync());
        matched.RootElement.GetProperty("matchedCount").GetInt32().Should().Be(0);
        matched.RootElement.GetProperty("ambiguousCount").GetInt32().Should().Be(1);
        var transaction = matched.RootElement.GetProperty("transactions").EnumerateArray().Single();
        transaction.GetProperty("matchStatus").GetString().Should().Be("Ambiguous");
        transaction.GetProperty("candidates")
            .EnumerateArray()
            .Select(item => item.GetProperty("journalEntryId").GetInt64())
            .Should()
            .Equal(candidates.OrderBy(item => item));
    }

    [Fact]
    public async Task Confirm_WithStaleVersion_ReturnsConflictAndDoesNotSelectCandidate()
    {
        var candidateIds = SeedTieCandidates("HID-STALE-A", "HID-STALE-B", 52m);
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-08-01",
            dateTo = "2026-08-31",
            transactions = new[]
            {
                new { transactionDate = "2026-08-10", amount = 52m, description = "Stale version row" }
            }
        });
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();
        var matchResponse = await _client.PostAsync($"/reconciliations/{reconciliationId}/auto-match", null);
        using var matched = JsonDocument.Parse(await matchResponse.Content.ReadAsStringAsync());
        var bankTransactionId = matched.RootElement.GetProperty("transactions")
            .EnumerateArray()
            .Single()
            .GetProperty("bankTransactionId")
            .GetInt64();

        var response = await _client.PostAsJsonAsync($"/reconciliations/{reconciliationId}/confirm", new
        {
            bankTransactionId,
            journalEntryId = candidateIds[0],
            expectedVersion = 1
        });

        response.StatusCode.Should().Be(HttpStatusCode.Conflict);

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var transaction = context.BankTransactions.Single(item => item.BankTransactionId == bankTransactionId);
        transaction.MatchedJournalEntryId.Should().BeNull();
        context.BankReconciliations.Single(item => item.ReconciliationId == reconciliationId)
            .Version
            .Should()
            .Be(2);
    }

    [Fact]
    public async Task Finalize_WithUnmatchedTransaction_ReturnsBadRequestAndKeepsDraftState()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-09-01",
            dateTo = "2026-09-30",
            transactions = new[]
            {
                new { transactionDate = "2026-09-10", amount = 12345m, description = "No candidate" }
            }
        });
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();

        var response = await _client.PostAsJsonAsync($"/reconciliations/{reconciliationId}/finalize", new
        {
            requestId = Guid.NewGuid(),
            expectedVersion = 1
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var reconciliation = context.BankReconciliations.Single(item => item.ReconciliationId == reconciliationId);
        reconciliation.Status.Should().Be("Draft");
        reconciliation.FinalizeRequestId.Should().BeNull();
        reconciliation.FinalizedAt.Should().BeNull();
    }

    [Fact]
    public async Task Exceptions_AsAuditor_ReturnsAmbiguousAndUnmatchedItems()
    {
        SeedTieCandidates("HID-AUDIT-A", "HID-AUDIT-B", 62m);
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var createResponse = await _client.PostAsJsonAsync("/reconciliations", new
        {
            periodId = TestDataFixture.OpenPeriodId,
            bankAccountId = TestDataFixture.AssetAccountId,
            dateFrom = "2026-10-01",
            dateTo = "2026-10-31",
            transactions = new[]
            {
                new { transactionDate = "2026-10-10", amount = 62m, description = "Ambiguous row" },
                new { transactionDate = "2026-10-11", amount = 99999m, description = "Unmatched row" }
            }
        });
        using var created = JsonDocument.Parse(await createResponse.Content.ReadAsStringAsync());
        var reconciliationId = created.RootElement.GetProperty("reconciliationId").GetGuid();
        var matchResponse = await _client.PostAsync($"/reconciliations/{reconciliationId}/auto-match", null);
        matchResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var response = await _client.GetAsync($"/reconciliations/{reconciliationId}/exceptions");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        using var payload = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        payload.RootElement.GetProperty("items").GetArrayLength().Should().Be(2);
    }

    private long[] SeedTieCandidates(string firstReference, string secondReference, decimal amount)
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var existing = context.JournalEntries
            .Where(item => item.ReferenceNo == firstReference || item.ReferenceNo == secondReference)
            .OrderBy(item => item.JournalEntryId)
            .Select(item => item.JournalEntryId)
            .ToArray();
        if (existing.Length == 2)
        {
            return existing;
        }

        var adminId = context.Users.Single(item => item.Username == TestDataFixture.AdminUsername).UserId;
        var entries = new[]
        {
            CreatePostedEntry(adminId, firstReference, amount),
            CreatePostedEntry(adminId, secondReference, amount)
        };
        context.JournalEntries.AddRange(entries);
        context.SaveChanges();
        return entries
            .OrderBy(item => item.JournalEntryId)
            .Select(item => item.JournalEntryId)
            .ToArray();
    }

    private static JournalEntry CreatePostedEntry(Guid actorId, string reference, decimal amount)
    {
        var entry = new JournalEntry
        {
            EntryDate = new DateTime(2026, 7, 10),
            Description = reference,
            ReferenceNo = reference,
            Status = "Posted",
            CreatedByUserId = actorId,
            CreatedAt = DateTime.UtcNow,
            PostedAt = DateTime.UtcNow
        };
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.AssetAccountId,
            Debit = amount,
            Credit = 0m
        });
        entry.Lines.Add(new JournalEntryLine
        {
            AccountId = TestDataFixture.LiabilityAccountId,
            Debit = 0m,
            Credit = amount
        });
        return entry;
    }
}
