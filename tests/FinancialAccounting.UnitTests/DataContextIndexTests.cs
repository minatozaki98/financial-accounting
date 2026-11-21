using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using MODEL;
using MODEL.Entities;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class DataContextIndexTests
{
    [Fact]
    public void JournalEntries_HasCompositeIndexForPostedPeriodReports()
    {
        using var context = CreateContext();

        var index = FindIndex<JournalEntry>(
            context,
            "IX_JournalEntries_Status_EntryDate_JournalEntryId");

        index.Properties.Select(property => property.Name)
            .Should()
            .Equal(
                nameof(JournalEntry.Status),
                nameof(JournalEntry.EntryDate),
                nameof(JournalEntry.JournalEntryId));
    }

    [Fact]
    public void JournalEntryLines_HasCoveringIndexForAccountLedgerReports()
    {
        using var context = CreateContext();

        var index = FindIndex<JournalEntryLine>(
            context,
            "IX_JournalEntryLines_AccountId_JournalEntryId_JournalEntryLineId");

        index.Properties.Select(property => property.Name)
            .Should()
            .Equal(
                nameof(JournalEntryLine.AccountId),
                nameof(JournalEntryLine.JournalEntryId),
                nameof(JournalEntryLine.JournalEntryLineId));
        index.FindAnnotation("SqlServer:Include")?.Value
            .Should()
            .BeEquivalentTo(new[]
            {
                nameof(JournalEntryLine.Debit),
                nameof(JournalEntryLine.Credit)
            });
    }

    private static DataContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<DataContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=FinancialAccountingIndexTests;Trusted_Connection=True")
            .Options;

        return new DataContext(options);
    }

    private static IIndex FindIndex<TEntity>(DataContext context, string databaseName)
        where TEntity : class
    {
        return context.Model.FindEntityType(typeof(TEntity))!
            .GetIndexes()
            .Single(index => index.GetDatabaseName() == databaseName);
    }
}
