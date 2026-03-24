using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using MODEL;
using MODEL.DTOs;
using System.Net;
using System.Net.Http.Json;
using System.Net.Http.Headers;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class ReportsTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;
    private readonly TestApiFactory _factory;
    private readonly TokenFixture _tokens;

    public ReportsTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    [Fact]
    public async Task TrialBalance_Admin_ReturnsOk()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var response = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Reports_User_ReturnsForbidden()
    {
        _client.SetBearer(await _tokens.GetUserTokenAsync());
        var response = await _client.GetAsync($"/reports/profit-loss?periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Ledger_InvalidAccount_ReturnsBadRequest()
    {
        _client.SetBearer(await _tokens.GetAuditorTokenAsync());
        var response = await _client.GetAsync($"/reports/account-ledger?accountId=999999&periodId={TestDataFixture.OpenPeriodId}");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task TrialBalance_DoesNotPersistReportSnapshots_ButWritesAuditLog()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        var before = GetReportSideEffects();

        var response = await _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var after = GetReportSideEffects();
        after.ReportCount.Should().Be(before.ReportCount);
        after.ReportItemCount.Should().Be(before.ReportItemCount);
        after.AuditLogCount.Should().Be(before.AuditLogCount + 1);
    }

    [Fact]
    public async Task TrialBalance_PopulatesLedgerBalancesForPeriod_WhenMissing()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());

        const int periodId = 202602;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var dbContext = setupScope.ServiceProvider.GetRequiredService<DataContext>();
            var adminUserId = dbContext.Users.Single(x => x.Username == TestDataFixture.AdminUsername).UserId;
            dbContext.AccountingPeriods.Add(new MODEL.Entities.AccountingPeriod
            {
                PeriodId = periodId,
                StartDate = new DateTime(2026, 2, 1),
                EndDate = new DateTime(2026, 2, 28),
                IsClosed = false
            });

            dbContext.JournalEntries.Add(new MODEL.Entities.JournalEntry
            {
                EntryDate = new DateTime(2026, 2, 10),
                Description = "Ledger balance warmup",
                ReferenceNo = "LEDGER-BALANCE-WARMUP",
                Status = "Posted",
                CreatedByUserId = adminUserId,
                CreatedAt = DateTime.UtcNow,
                PostedAt = DateTime.UtcNow,
                Lines =
                {
                    new MODEL.Entities.JournalEntryLine
                    {
                        AccountId = TestDataFixture.AssetAccountId,
                        Debit = 40m,
                        Credit = 0m,
                        LineDescription = "Debit cash"
                    },
                    new MODEL.Entities.JournalEntryLine
                    {
                        AccountId = TestDataFixture.LiabilityAccountId,
                        Debit = 0m,
                        Credit = 40m,
                        LineDescription = "Credit payable"
                    }
                }
            });

            dbContext.SaveChanges();
            dbContext.LedgerBalances.Where(x => x.PeriodId == periodId).Should().BeEmpty();
        }

        var response = await _client.GetAsync($"/reports/trial-balance?periodId={periodId}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        using var afterScope = _factory.Services.CreateScope();
        var afterDb = afterScope.ServiceProvider.GetRequiredService<DataContext>();
        var balances = afterDb.LedgerBalances
            .Where(x => x.PeriodId == periodId)
            .OrderBy(x => x.AccountId)
            .ToList();

        balances.Should().HaveCount(2);

        var assetBalance = balances.Single(x => x.AccountId == TestDataFixture.AssetAccountId);
        assetBalance.DebitTotal.Should().Be(40m);
        assetBalance.CreditTotal.Should().Be(0m);
        assetBalance.Balance.Should().Be(40m);

        var liabilityBalance = balances.Single(x => x.AccountId == TestDataFixture.LiabilityAccountId);
        liabilityBalance.DebitTotal.Should().Be(0m);
        liabilityBalance.CreditTotal.Should().Be(40m);
        liabilityBalance.Balance.Should().Be(40m);
    }

    [Fact]
    public async Task AccountLedger_PostedEntryReflectsUpdatedBalanceAfterCacheWarmup()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        const int periodId = 202701;

        using (var setupScope = _factory.Services.CreateScope())
        {
            var dbContext = setupScope.ServiceProvider.GetRequiredService<DataContext>();
            if (!dbContext.AccountingPeriods.Any(x => x.PeriodId == periodId))
            {
                dbContext.AccountingPeriods.Add(new MODEL.Entities.AccountingPeriod
                {
                    PeriodId = periodId,
                    StartDate = new DateTime(2027, 1, 1),
                    EndDate = new DateTime(2027, 1, 31),
                    IsClosed = false
                });
                dbContext.SaveChanges();
            }
        }

        var before = await _client.GetFromJsonAsync<AccountLedgerResponseDto>(
            $"/reports/account-ledger?accountId={TestDataFixture.AssetAccountId}&periodId={periodId}");

        var createResponse = await _client.PostAsJsonAsync("/journal-entries", new
        {
            entryDate = "2027-01-10",
            description = "Cache invalidation ledger entry",
            referenceNo = "CACHE-LEDGER-POST",
            lines = new[]
            {
                new { accountId = TestDataFixture.AssetAccountId, debit = 25m, credit = 0m },
                new { accountId = TestDataFixture.LiabilityAccountId, debit = 0m, credit = 25m }
            }
        });

        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        var created = await createResponse.Content.ReadFromJsonAsync<JournalEntryResponseDto>();
        created.Should().NotBeNull();

        var postResponse = await _client.PostAsync($"/journal-entries/{created!.JournalEntryId}/post", content: null);
        postResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        var after = await _client.GetFromJsonAsync<AccountLedgerResponseDto>(
            $"/reports/account-ledger?accountId={TestDataFixture.AssetAccountId}&periodId={periodId}");

        after.Should().NotBeNull();
        after!.ClosingBalance.Should().Be(before!.ClosingBalance + 25m);
        after.Lines.Should().HaveCount(before.Lines.Count + 1);
        after.Lines.Last().ReferenceNo.Should().Be("CACHE-LEDGER-POST");
    }

    [Fact]
    public async Task AccountLedger_CompressesJsonResponse_WhenClientRequestsGzip()
    {
        _client.SetBearer(await _tokens.GetAdminTokenAsync());
        _client.DefaultRequestHeaders.AcceptEncoding.Clear();
        _client.DefaultRequestHeaders.AcceptEncoding.Add(new StringWithQualityHeaderValue("gzip"));

        var response = await _client.GetAsync(
            $"/reports/account-ledger?accountId={TestDataFixture.AssetAccountId}&periodId={TestDataFixture.OpenPeriodId}");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Content.Headers.ContentEncoding.Should().Contain("gzip");
    }

    private (int ReportCount, int ReportItemCount, int AuditLogCount) GetReportSideEffects()
    {
        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<DataContext>();

        return (
            dbContext.Reports.Count(),
            dbContext.ReportItems.Count(),
            dbContext.AuditLogs.Count());
    }
}
