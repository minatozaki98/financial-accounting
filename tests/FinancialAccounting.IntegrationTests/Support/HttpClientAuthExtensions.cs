using System.Net.Http.Headers;

namespace FinancialAccounting.IntegrationTests.Support;

public static class HttpClientAuthExtensions
{
    public static void SetBearer(this HttpClient client, string token)
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (!client.DefaultRequestHeaders.Contains("X-Api-Version"))
        {
            client.DefaultRequestHeaders.Add("X-Api-Version", "1.0");
        }
    }

    public static void ClearAuth(this HttpClient client)
    {
        client.DefaultRequestHeaders.Authorization = null;
    }
}
