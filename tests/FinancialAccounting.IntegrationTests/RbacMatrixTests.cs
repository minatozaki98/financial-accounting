using FinancialAccounting.IntegrationTests.Fixtures;
using FinancialAccounting.IntegrationTests.Support;
using FluentAssertions;
using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class RbacMatrixTests : IClassFixture<TestApiFactory>
{
    private static readonly string[] Roles = { "Admin", "FinanceManager", "User", "Auditor", "Anonymous" };
    private static readonly int[] AllowedPeriodCloseStatuses = { 204, 404 };

    private readonly HttpClient _client;
    private readonly TokenFixture _tokens;

    public RbacMatrixTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
        _tokens = new TokenFixture(_client);
    }

    public static TheoryData<string, string> Cases { get; } = CreateCases();

    private static TheoryData<string, string> CreateCases()
    {
        var data = new TheoryData<string, string>();
        foreach (var endpoint in ExpectedStatusMatrix.EndpointRoleStatus.Keys)
        {
            foreach (var role in Roles)
            {
                data.Add(endpoint, role);
            }
        }

        return data;
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public async Task EndpointRoleMatrix_MatchesExpectedStatus(string endpointKey, string role)
    {
        await ApplyRoleAsync(role);

        using var response = await SendAsync(endpointKey, role);
        var expectedStatus = ExpectedStatusMatrix.EndpointRoleStatus[endpointKey][role];

        var actual = (int)response.StatusCode;
        if (endpointKey == "POST /periods/{id}/close" && (role == "Admin" || role == "FinanceManager"))
        {
            AllowedPeriodCloseStatuses.Should().Contain(actual);
            return;
        }

        actual.Should().Be(expectedStatus, $"endpoint '{endpointKey}' role '{role}' should map to expected status");
    }

    private async Task ApplyRoleAsync(string role)
    {
        _client.ClearAuth();
        if (role == "Anonymous")
        {
            return;
        }

        var token = role switch
        {
            "Admin" => await _tokens.GetAdminTokenAsync(),
            "FinanceManager" => await _tokens.GetFinanceManagerTokenAsync(),
            "User" => await _tokens.GetUserTokenAsync(),
            "Auditor" => await _tokens.GetAuditorTokenAsync(),
            _ => throw new InvalidOperationException($"Unknown role {role}")
        };

        _client.SetBearer(token);
    }

    private Task<HttpResponseMessage> SendAsync(string endpointKey, string role)
    {
        return endpointKey switch
        {
            "GET /users/me" => _client.GetAsync("/users/me"),
            "POST /users" => _client.PostAsJsonAsync("/users", new
            {
                username = $"rbac-{Guid.NewGuid():N}"[..12],
                email = $"rbac-{Guid.NewGuid():N}@local.invalid",
                password = "User@12345!",
                role = "User"
            }),
            "GET /accounts" => _client.GetAsync("/accounts"),
            "POST /accounts" => _client.PostAsJsonAsync("/accounts", new
            {
                accountCode = $"R{DateTime.UtcNow:HHmmss}",
                accountName = "RBAC account",
                accountType = "Asset",
                isActive = true
            }),
            "GET /periods" => _client.GetAsync("/periods"),
            "POST /periods" => _client.PostAsJsonAsync("/periods", new
            {
                periodId = 210000 + Random.Shared.Next(1, 999),
                startDate = "2100-01-01",
                endDate = "2100-12-31"
            }),
            "POST /periods/{id}/close" => _client.PostAsync($"/periods/{TestDataFixture.ClosedPeriodId}/close", null),
            "POST /journal-entries" => _client.PostAsJsonAsync("/journal-entries", new
            {
                entryDate = "2026-03-01",
                lines = new[]
                {
                    new { accountId = TestDataFixture.AssetAccountId, debit = 25, credit = 0 },
                    new { accountId = TestDataFixture.LiabilityAccountId, debit = 0, credit = 25 }
                }
            }),
            "POST /journal-entries/bulk" => _client.PostAsJsonAsync("/journal-entries/bulk", new
            {
                entries = new[]
                {
                    new
                    {
                        entryDate = "2026-03-01",
                        lines = new[]
                        {
                            new { accountId = TestDataFixture.AssetAccountId, debit = 20, credit = 0 },
                            new { accountId = TestDataFixture.LiabilityAccountId, debit = 0, credit = 20 }
                        }
                    }
                }
            }),
            "POST /journal-entries/{id}/post" => _client.PostAsync($"/journal-entries/{ResolvePostTargetId(role)}/post", null),
            "POST /journal-entries/{id}/reverse" => _client.PostAsync($"/journal-entries/{ResolveReverseTargetId(role)}/reverse", null),
            "DELETE /journal-entries/{id}" => _client.DeleteAsync($"/journal-entries/{TestDataFixture.PostedEntryId}"),
            "GET /reports/trial-balance" => _client.GetAsync($"/reports/trial-balance?periodId={TestDataFixture.OpenPeriodId}"),
            "GET /audit-logs" => _client.GetAsync("/audit-logs?page=1&pageSize=10"),
            _ => throw new InvalidOperationException($"Unknown endpoint key: {endpointKey}")
        };
    }

    private static long ResolvePostTargetId(string role)
    {
        return role.Equals("Admin", StringComparison.OrdinalIgnoreCase)
            ? TestDataFixture.MatrixDraftEntryId
            : TestDataFixture.PostedEntryId;
    }

    private static long ResolveReverseTargetId(string role)
    {
        return role switch
        {
            "Admin" => TestDataFixture.MatrixReverseAdminEntryId,
            "FinanceManager" => TestDataFixture.MatrixReverseFinanceEntryId,
            _ => TestDataFixture.PostedEntryId
        };
    }
}
