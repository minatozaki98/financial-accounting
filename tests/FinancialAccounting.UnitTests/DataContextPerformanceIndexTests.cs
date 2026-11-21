using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using MODEL;
using MODEL.Entities;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class DataContextPerformanceIndexTests
{
    [Fact]
    public void JournalEntryIndexes_ShouldSupportReportAndLedgerLookups()
    {
        var options = new DbContextOptionsBuilder<DataContext>()
            .UseSqlServer("Server=(localdb)\\MSSQLLocalDB;Database=PerformanceIndexTests;Integrated Security=true;TrustServerCertificate=true")
            .Options;
        using var context = new DataContext(options);

        var journalEntryIndexes = context.Model
            .FindEntityType(typeof(JournalEntry))!
            .GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToList();
        var journalEntryLineIndexes = context.Model
            .FindEntityType(typeof(JournalEntryLine))!
            .GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToList();

        journalEntryIndexes.Should().Contain(index => index.SequenceEqual(new[] { nameof(JournalEntry.Status), nameof(JournalEntry.EntryDate) }));
        journalEntryLineIndexes.Should().Contain(index => index.SequenceEqual(new[] { nameof(JournalEntryLine.AccountId), nameof(JournalEntryLine.JournalEntryId) }));
    }
}
