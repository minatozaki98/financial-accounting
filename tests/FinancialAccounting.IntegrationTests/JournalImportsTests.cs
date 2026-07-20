using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class JournalImportsTests : IClassFixture<TestApiFactory>
{
    private const string Header = "EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit";
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public JournalImportsTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task Validate_WithBalancedCsv_StagesRowsAndReplaysIdempotently()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var idempotencyKey = $"valid-{Guid.NewGuid():N}";
        var csv = string.Join(
            "\n",
            Header,
            "2026-04-01,IMP-VALID-1,Imported debit,A1000,150.00,0",
            "2026-04-01,IMP-VALID-1,Imported credit,L1000,0,150.00");

        var firstResponse = await PostValidationAsync(csv, idempotencyKey, atomic: true);

        firstResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var first = JsonDocument.Parse(await firstResponse.Content.ReadAsStringAsync());
        var importId = first.RootElement.GetProperty("importId").GetGuid();
        first.RootElement.GetProperty("totalRows").GetInt32().Should().Be(2);
        first.RootElement.GetProperty("invalidRows").GetInt32().Should().Be(0);
        first.RootElement.GetProperty("replayed").GetBoolean().Should().BeFalse();

        var replayResponse = await PostValidationAsync(csv, idempotencyKey, atomic: true);

        replayResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayResponse.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("importId").GetGuid().Should().Be(importId);
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();
    }

    [Fact]
    public async Task Commit_AtomicInvalidBatch_ReturnsBadRequest()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var csv = string.Join(
            "\n",
            Header,
            "2026-04-02,IMP-INVALID-1,Only debit,A1000,25.00,0");
        var validationResponse = await PostValidationAsync(
            csv,
            $"invalid-{Guid.NewGuid():N}",
            atomic: true);
        using var validation = JsonDocument.Parse(await validationResponse.Content.ReadAsStringAsync());
        var importId = validation.RootElement.GetProperty("importId").GetGuid();
        validation.RootElement.GetProperty("invalidRows").GetInt32().Should().Be(1);

        var commitResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);

        commitResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Commit_ValidBatch_CreatesDraftOnceAndReplays()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var reference = $"IMP-COMMIT-{Guid.NewGuid():N}"[..30];
        var csv = string.Join(
            "\n",
            Header,
            $"2026-04-03,{reference},Imported debit,A1000,75.00,0",
            $"2026-04-03,{reference},Imported credit,L1000,0,75.00");
        var validationResponse = await PostValidationAsync(
            csv,
            $"commit-{Guid.NewGuid():N}",
            atomic: true);
        using var validation = JsonDocument.Parse(await validationResponse.Content.ReadAsStringAsync());
        var importId = validation.RootElement.GetProperty("importId").GetGuid();

        var commitResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);

        commitResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var committed = JsonDocument.Parse(await commitResponse.Content.ReadAsStringAsync());
        var createdIds = committed.RootElement.GetProperty("createdEntryIds")
            .EnumerateArray()
            .Select(item => item.GetInt64())
            .ToArray();
        createdIds.Should().ContainSingle();
        committed.RootElement.GetProperty("replayed").GetBoolean().Should().BeFalse();

        var replayResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);
        replayResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayResponse.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("createdEntryIds")
            .EnumerateArray()
            .Select(item => item.GetInt64())
            .Should()
            .Equal(createdIds);
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        context.JournalEntries.Count(item => item.ImportBatchId == importId).Should().Be(1);
        context.JournalEntries.Single(item => item.ImportBatchId == importId).Status.Should().Be("Draft");
        context.AuditLogs.Count(item => item.Action == "COMMIT_JOURNAL_IMPORT" && item.EntityId == importId.ToString())
            .Should()
            .Be(1);
    }

    [Fact]
    public async Task Validate_AsAuditor_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());

        var response = await PostValidationAsync(
            Header,
            $"forbidden-{Guid.NewGuid():N}",
            atomic: true);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    private async Task<HttpResponseMessage> PostValidationAsync(
        string csv,
        string idempotencyKey,
        bool atomic)
    {
        using var content = new MultipartFormDataContent();
        var file = new ByteArrayContent(Encoding.UTF8.GetBytes(csv));
        file.Headers.ContentType = new MediaTypeHeaderValue("text/csv");
        content.Add(file, "file", "journal-import.csv");
        content.Add(new StringContent(idempotencyKey), "idempotencyKey");
        content.Add(new StringContent(atomic.ToString()), "atomic");
        return await _client.PostAsync("/journal-imports/validate", content);
    }
}
