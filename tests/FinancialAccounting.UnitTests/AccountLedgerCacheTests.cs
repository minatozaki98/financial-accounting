using BAL.Shared;
using FluentAssertions;
using MODEL.DTOs;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class AccountLedgerCacheTests
{
    [Fact]
    public async Task GetOrCreateAsync_ReusesSnapshotForSameKey()
    {
        var cache = new AccountLedgerCache();
        var factoryCalls = 0;

        var first = await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                factoryCalls++;
                return Task.FromResult(CreateSnapshot(100m));
            });

        var second = await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                factoryCalls++;
                return Task.FromResult(CreateSnapshot(200m));
            });

        factoryCalls.Should().Be(1);
        second.Should().BeSameAs(first);
        second.ClosingBalance.Should().Be(100m);
    }

    [Fact]
    public async Task Invalidate_RemovesAllSnapshotsForAccountAndPeriod()
    {
        var cache = new AccountLedgerCache();
        var firstFactoryCalls = 0;
        var secondFactoryCalls = 0;

        await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                firstFactoryCalls++;
                return Task.FromResult(CreateSnapshot(100m));
            });

        await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 6, 30),
            factory: () =>
            {
                secondFactoryCalls++;
                return Task.FromResult(CreateSnapshot(150m));
            });

        cache.Invalidate(accountId: 1, periodId: 202601);

        var refreshedFirst = await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                firstFactoryCalls++;
                return Task.FromResult(CreateSnapshot(250m));
            });

        var refreshedSecond = await cache.GetOrCreateAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 6, 30),
            factory: () =>
            {
                secondFactoryCalls++;
                return Task.FromResult(CreateSnapshot(350m));
            });

        firstFactoryCalls.Should().Be(2);
        secondFactoryCalls.Should().Be(2);
        refreshedFirst.ClosingBalance.Should().Be(250m);
        refreshedSecond.ClosingBalance.Should().Be(350m);
    }

    [Fact]
    public async Task GetOrCreatePayloadAsync_ReusesSerializedPayloadForSameKey()
    {
        var cache = new AccountLedgerCache();
        var factoryCalls = 0;

        var first = await cache.GetOrCreatePayloadAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                factoryCalls++;
                return Task.FromResult(CreatePayload(100m, 1));
            });

        var second = await cache.GetOrCreatePayloadAsync(
            accountId: 1,
            periodId: 202601,
            accountType: "Asset",
            startDate: new DateTime(2026, 1, 1),
            endDate: new DateTime(2026, 12, 31),
            factory: () =>
            {
                factoryCalls++;
                return Task.FromResult(CreatePayload(200m, 2));
            });

        factoryCalls.Should().Be(1);
        second.Should().BeSameAs(first);
        second.Response.ClosingBalance.Should().Be(100m);
        second.JsonUtf8.Should().Equal(new byte[] { 1 });
    }

    private static AccountLedgerSnapshot CreateSnapshot(decimal closingBalance)
    {
        return new AccountLedgerSnapshot(
            OpeningBalance: 0m,
            ClosingBalance: closingBalance,
            DebitTotal: closingBalance,
            CreditTotal: 0m,
            Lines: new List<AccountLedgerLineDto>
            {
                new()
                {
                    EntryDate = new DateTime(2026, 1, 1),
                    JournalEntryId = 1,
                    ReferenceNo = "TEST-1",
                    EntryDescription = "Test",
                    LineDescription = "Test",
                    Debit = closingBalance,
                    Credit = 0m,
                    RunningBalance = closingBalance
                }
            });
    }

    private static AccountLedgerPayload CreatePayload(decimal closingBalance, byte marker)
    {
        return new AccountLedgerPayload(
            Response: new AccountLedgerResponseDto
            {
                PeriodId = 202601,
                AccountId = 1,
                AccountCode = "A000001",
                AccountName = "Cash",
                AccountType = "Asset",
                StartDate = new DateTime(2026, 1, 1),
                EndDate = new DateTime(2026, 12, 31),
                OpeningBalance = 0m,
                ClosingBalance = closingBalance,
                Lines = new List<AccountLedgerLineDto>()
            },
            DebitTotal: closingBalance,
            CreditTotal: 0m,
            JsonUtf8: new[] { marker });
    }
}
