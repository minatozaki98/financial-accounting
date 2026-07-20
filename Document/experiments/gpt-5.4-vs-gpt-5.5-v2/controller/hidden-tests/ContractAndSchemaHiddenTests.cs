using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using MODEL.Entities;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace FinancialAccounting.BenchmarkHiddenTests;

public sealed class ContractAndSchemaHiddenTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;
    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public ContractAndSchemaHiddenTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task Swagger_ContainsComplexWorkflowRoutesAndMultipartContract()
    {
        var response = await _client.GetAsync("/swagger/v1/swagger.json");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var swagger = await response.Content.ReadAsStringAsync();
        swagger.Should().Contain("/periods/{periodId}/close-preview");
        swagger.Should().Contain("/periods/{periodId}/close");
        swagger.Should().Contain("/journal-imports/validate");
        swagger.Should().Contain("/journal-imports/{importId}/commit");
        swagger.Should().Contain("/reconciliations/{reconciliationId}/auto-match");
        swagger.Should().Contain("/reconciliations/{reconciliationId}/finalize");
        swagger.Should().Contain("multipart/form-data");
    }

    [Fact]
    public async Task AuthorizationBoundaries_ReturnExpectedStatusesBeforeModelBindingWork()
    {
        var unauthorizedPreview = await _client.GetAsync($"/periods/{TestDataFixture.OpenPeriodId}/close-preview");
        unauthorizedPreview.StatusCode.Should().Be(HttpStatusCode.Unauthorized);

        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var forbiddenImport = await PostMinimalJournalImportAsync();
        forbiddenImport.StatusCode.Should().Be(HttpStatusCode.Forbidden);

        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var forbiddenReconciliation = await _client.PostAsJsonAsync("/reconciliations", new
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
        forbiddenReconciliation.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public void EfModel_KeepsConcurrencyPrecisionAndUniqueIndexes()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();
        var model = context.Model;

        var period = model.FindEntityType(typeof(AccountingPeriod));
        period.Should().NotBeNull();
        period!.FindProperty(nameof(AccountingPeriod.Version))!.IsConcurrencyToken.Should().BeTrue();
        period.GetIndexes().Should().Contain(index =>
            index.Properties.Select(property => property.Name).SequenceEqual(new[] { nameof(AccountingPeriod.CloseRequestId) }) &&
            index.IsUnique);

        var reconciliation = model.FindEntityType(typeof(BankReconciliation));
        reconciliation.Should().NotBeNull();
        reconciliation!.FindProperty(nameof(BankReconciliation.Version))!.IsConcurrencyToken.Should().BeTrue();
        reconciliation.GetIndexes().Should().Contain(index =>
            index.Properties.Select(property => property.Name).SequenceEqual(new[] { nameof(BankReconciliation.FinalizeRequestId) }) &&
            index.IsUnique);

        var transaction = model.FindEntityType(typeof(BankTransaction));
        transaction.Should().NotBeNull();
        transaction!.FindProperty(nameof(BankTransaction.Amount))!.GetPrecision().Should().Be(18);
        transaction.FindProperty(nameof(BankTransaction.Amount))!.GetScale().Should().Be(2);

        var importRows = model.FindEntityType(typeof(JournalImportRow));
        importRows.Should().NotBeNull();
        importRows!.GetIndexes().Should().Contain(index =>
            index.Properties.Select(property => property.Name).SequenceEqual(new[]
            {
                nameof(JournalImportRow.ImportId),
                nameof(JournalImportRow.RowNumber)
            }) && index.IsUnique);
    }

    private async Task<HttpResponseMessage> PostMinimalJournalImportAsync()
    {
        using var content = new MultipartFormDataContent();
        var file = new ByteArrayContent("EntryDate,ReferenceNo,Description,AccountCode,Debit,Credit"u8.ToArray());
        content.Add(file, "file", "journal-import.csv");
        content.Add(new StringContent($"hidden-{Guid.NewGuid():N}"), "idempotencyKey");
        content.Add(new StringContent("true"), "atomic");
        return await _client.PostAsync("/journal-imports/validate", content);
    }
}
