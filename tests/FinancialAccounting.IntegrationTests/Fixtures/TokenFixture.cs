using System.Net.Http.Json;
using System.Text.Json;

namespace FinancialAccounting.IntegrationTests.Fixtures;

public sealed class TokenFixture
{
    private readonly HttpClient _client;

    public TokenFixture(HttpClient client)
    {
        _client = client;
    }

    public Task<string> GetAdminTokenAsync()
    {
        return GetTokenAsync(TestDataFixture.AdminUsername, TestDataFixture.DefaultPassword);
    }

    public Task<string> GetFinanceManagerTokenAsync()
    {
        return GetTokenAsync(TestDataFixture.FinanceManagerUsername, TestDataFixture.DefaultPassword);
    }

    public Task<string> GetUserTokenAsync()
    {
        return GetTokenAsync(TestDataFixture.UserUsername, TestDataFixture.DefaultPassword);
    }

    public Task<string> GetAuditorTokenAsync()
    {
        return GetTokenAsync(TestDataFixture.AuditorUsername, TestDataFixture.DefaultPassword);
    }

    private async Task<string> GetTokenAsync(string username, string password)
    {
        using var response = await _client.PostAsJsonAsync("/auth/login", new
        {
            username,
            password
        });

        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>();
        if (!payload.TryGetProperty("accessToken", out var tokenNode))
        {
            throw new InvalidOperationException("Token response did not include accessToken.");
        }

        var token = tokenNode.GetString();
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new InvalidOperationException("Token value was empty.");
        }

        return token;
    }
}
