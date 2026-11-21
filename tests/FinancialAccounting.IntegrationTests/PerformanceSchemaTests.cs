using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using System.Data.Common;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class PerformanceSchemaTests : IClassFixture<TestApiFactory>
{
    private readonly TestApiFactory _factory;

    public PerformanceSchemaTests(TestApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task ReportReadIndexes_CombineThePostedDateFilterAndLedgerJoinKeys()
    {
        await using var scope = _factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<DataContext>();

        var postedDateIndex = await GetIndexColumnsAsync(
            context,
            "IX_JournalEntries_Status_EntryDate_JournalEntryId");
        var ledgerJoinIndex = await GetIndexColumnsAsync(
            context,
            "IX_JournalEntryLines_AccountId_JournalEntryId");

        postedDateIndex.Should().Equal("Status", "EntryDate", "JournalEntryId");
        ledgerJoinIndex.Should().Equal("AccountId", "JournalEntryId");
    }

    private static async Task<List<string>> GetIndexColumnsAsync(DataContext context, string indexName)
    {
        var connection = context.Database.GetDbConnection();
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT [name] FROM pragma_index_info($indexName) ORDER BY [seqno]";

        var indexNameParameter = command.CreateParameter();
        indexNameParameter.ParameterName = "$indexName";
        indexNameParameter.Value = indexName;
        command.Parameters.Add(indexNameParameter);

        var columns = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            columns.Add(reader.GetString(0));
        }

        return columns;
    }
}
