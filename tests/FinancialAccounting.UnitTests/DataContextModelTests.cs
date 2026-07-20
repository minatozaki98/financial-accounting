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

    [Fact]
    public void DataContext_DefinesPeriodCloseConcurrencyAndIdempotency()
    {
        using var context = CreateContext();

        var period = context.Model.FindEntityType(typeof(AccountingPeriod))!;

        period.FindProperty("Version")!.IsConcurrencyToken.Should().BeTrue();
        period.GetIndexes().Should().Contain(index =>
            index.IsUnique &&
            index.Properties.Select(property => property.Name).SequenceEqual(new[] { "CloseRequestId" }));
    }

    [Fact]
    public void DataContext_DefinesJournalImportPersistenceContract()
    {
        using var context = CreateContext();

        var batch = context.Model.FindEntityType("MODEL.Entities.JournalImportBatch");
        var row = context.Model.FindEntityType("MODEL.Entities.JournalImportRow");

        batch.Should().NotBeNull();
        row.Should().NotBeNull();
        batch!.GetIndexes().Should().Contain(index =>
            index.IsUnique &&
            index.Properties.Select(property => property.Name)
                .SequenceEqual(new[] { "CreatedByUserId", "IdempotencyKey" }));
        row!.FindProperty("Debit")!.GetPrecision().Should().Be(18);
        row.FindProperty("Debit")!.GetScale().Should().Be(2);
        row.FindProperty("Credit")!.GetPrecision().Should().Be(18);
        row.FindProperty("Credit")!.GetScale().Should().Be(2);
    }

    [Fact]
    public void DataContext_DefinesReconciliationConcurrencyAndCandidateUniqueness()
    {
        using var context = CreateContext();

        var reconciliation = context.Model.FindEntityType("MODEL.Entities.BankReconciliation");
        var transaction = context.Model.FindEntityType("MODEL.Entities.BankTransaction");
        var candidate = context.Model.FindEntityType("MODEL.Entities.BankReconciliationCandidate");

        reconciliation.Should().NotBeNull();
        transaction.Should().NotBeNull();
        candidate.Should().NotBeNull();
        reconciliation!.FindProperty("Version")!.IsConcurrencyToken.Should().BeTrue();
        reconciliation.GetIndexes().Should().Contain(index =>
            index.IsUnique &&
            index.Properties.Select(property => property.Name).SequenceEqual(new[] { "FinalizeRequestId" }));
        transaction!.FindProperty("Amount")!.GetPrecision().Should().Be(18);
        transaction.FindProperty("Amount")!.GetScale().Should().Be(2);
        candidate!.GetIndexes().Should().Contain(index =>
            index.IsUnique &&
            index.Properties.Select(property => property.Name)
                .SequenceEqual(new[] { "BankTransactionId", "JournalEntryId" }));
    }

    private static DataContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<DataContext>()
            .UseSqlServer("Server=(localdb)\\mssqllocaldb;Database=FinancialAccountingModelTests;Trusted_Connection=True;TrustServerCertificate=True;")
            .Options;

        return new DataContext(options);
    }
}
