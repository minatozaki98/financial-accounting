using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.Entities;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class DataContextModelTests
{
    [Fact]
    public void DataContext_DefinesCompositeIndexesForLedgerQueryHotPaths()
    {
        using var context = CreateContext();

        var journalEntryIndexes = context.Model.FindEntityType(typeof(JournalEntry))!
            .GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToList();

        journalEntryIndexes.Should().Contain(index =>
            index.SequenceEqual(new[] { nameof(JournalEntry.Status), nameof(JournalEntry.EntryDate), nameof(JournalEntry.JournalEntryId) }));

        var journalEntryLineIndexes = context.Model.FindEntityType(typeof(JournalEntryLine))!
            .GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToList();

        journalEntryLineIndexes.Should().Contain(index =>
            index.SequenceEqual(new[] { nameof(JournalEntryLine.AccountId), nameof(JournalEntryLine.JournalEntryId), nameof(JournalEntryLine.JournalEntryLineId) }));
    }

    private static DataContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<DataContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=FinancialAccountingModelTests;Trusted_Connection=True;TrustServerCertificate=True;")
            .Options;

        return new DataContext(options);
    }
}
