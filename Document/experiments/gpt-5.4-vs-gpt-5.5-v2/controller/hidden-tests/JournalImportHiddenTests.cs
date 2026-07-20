using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.BenchmarkHiddenTests;

public sealed class JournalImportHiddenTests : IClassFixture<TestApiFactory>
{
    private const string Header = "EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit";
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public JournalImportHiddenTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task Validate_WithQuotedCommaAndEscapedQuote_CommitsParsedDescription()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var reference = $"HID-Q-{Guid.NewGuid():N}"[..30];
        var csv = string.Join(
            "\n",
            Header,
            $"2026-04-01,{reference},\"Debit, \"\"quoted\"\" memo\",A1000,150.00,0",
            $"2026-04-01,{reference},\"Credit, mirror\",L1000,0,150.00");

        var validationResponse = await PostValidationAsync(csv, $"quote-{Guid.NewGuid():N}", atomic: true);

        validationResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var validation = JsonDocument.Parse(await validationResponse.Content.ReadAsStringAsync());
        validation.RootElement.GetProperty("invalidRows").GetInt32().Should().Be(0);
        var importId = validation.RootElement.GetProperty("importId").GetGuid();

        var commitResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);

        commitResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var entry = context.JournalEntries
            .Include(item => item.Lines)
            .Single(item => item.ReferenceNo == reference);
        entry.Description.Should().Be("Debit, \"quoted\" memo");
        entry.Lines.Count.Should().Be(2);
    }

    [Fact]
    public async Task Validate_AllowsExactlyTenThousandRows()
    {
        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var csv = BuildBalancedCsv(10000);

        var response = await PostValidationAsync(csv, $"rows-{Guid.NewGuid():N}", atomic: true);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        using var payload = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        payload.RootElement.GetProperty("totalRows").GetInt32().Should().Be(10000);
        payload.RootElement.GetProperty("validRows").GetInt32().Should().Be(10000);
        payload.RootElement.GetProperty("invalidRows").GetInt32().Should().Be(0);
    }

    [Fact]
    public async Task Commit_IsScopedToActorAndReplayDoesNotDuplicateEntries()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var reference = $"HID-ACTOR-{Guid.NewGuid():N}"[..30];
        var csv = string.Join(
            "\n",
            Header,
            $"2026-04-03,{reference},Debit,A1000,75.00,0",
            $"2026-04-03,{reference},Credit,L1000,0,75.00");
        var validationResponse = await PostValidationAsync(csv, $"actor-{Guid.NewGuid():N}", atomic: true);
        using var validation = JsonDocument.Parse(await validationResponse.Content.ReadAsStringAsync());
        var importId = validation.RootElement.GetProperty("importId").GetGuid();

        _client.SetBearer(await _tokens.GetFinanceManagerTokenAsync());
        var otherActorResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);
        otherActorResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);

        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var firstCommit = await _client.PostAsync($"/journal-imports/{importId}/commit", null);
        firstCommit.StatusCode.Should().Be(HttpStatusCode.OK);
        var replayCommit = await _client.PostAsync($"/journal-imports/{importId}/commit", null);
        replayCommit.StatusCode.Should().Be(HttpStatusCode.OK);
        using var replay = JsonDocument.Parse(await replayCommit.Content.ReadAsStringAsync());
        replay.RootElement.GetProperty("replayed").GetBoolean().Should().BeTrue();

        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        context.JournalEntries.Count(item => item.ReferenceNo == reference).Should().Be(1);
    }

    [Fact]
    public async Task Commit_AtomicDuplicateReferenceCreatesNoNewEntry()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var existingCount = CountEntriesByReference("SEED-POSTED");
        var csv = string.Join(
            "\n",
            Header,
            "2026-04-04,SEED-POSTED,Duplicate debit,A1000,25.00,0",
            "2026-04-04,SEED-POSTED,Duplicate credit,L1000,0,25.00");

        var validationResponse = await PostValidationAsync(csv, $"duplicate-{Guid.NewGuid():N}", atomic: true);
        validationResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        using var validation = JsonDocument.Parse(await validationResponse.Content.ReadAsStringAsync());
        validation.RootElement.GetProperty("invalidRows").GetInt32().Should().Be(2);
        var importId = validation.RootElement.GetProperty("importId").GetGuid();

        var commitResponse = await _client.PostAsync($"/journal-imports/{importId}/commit", null);

        commitResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        CountEntriesByReference("SEED-POSTED").Should().Be(existingCount);
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

    private static string BuildBalancedCsv(int rowCount)
    {
        var builder = new StringBuilder();
        builder.AppendLine(Header);
        for (var row = 1; row <= rowCount; row++)
        {
            var pair = (row + 1) / 2;
            var reference = $"HID-10000-{pair:D5}";
            if (row % 2 == 1)
            {
                builder.AppendLine($"2026-04-02,{reference},Debit,A1000,1.00,0");
            }
            else
            {
                builder.AppendLine($"2026-04-02,{reference},Credit,L1000,0,1.00");
            }
        }

        return builder.ToString();
    }

    private int CountEntriesByReference(string reference)
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        return context.JournalEntries.Count(item => item.ReferenceNo == reference);
    }
}
