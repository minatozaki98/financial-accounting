using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class SecurityHeadersTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public SecurityHeadersTests(TestApiFactory factory)
    {
        _client = factory.CreateClient(new() { AllowAutoRedirect = false });
    }

    [Theory]
    [InlineData("/")]
    [InlineData("/swagger/index.html")]
    [InlineData("/swagger/v1/swagger.json")]
    public async Task BrowserReachableResponses_IncludeSecurityHeaders(string path)
    {
        var response = await _client.GetAsync(path);

        response.Headers.GetValues("Content-Security-Policy")
            .Should().ContainSingle("default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'none';");
        response.Headers.GetValues("X-Content-Type-Options").Should().ContainSingle("nosniff");
        response.Headers.GetValues("Permissions-Policy").Should().ContainSingle("camera=(), microphone=(), geolocation=()");
        response.Headers.GetValues("Cross-Origin-Opener-Policy").Should().ContainSingle("same-origin");
        response.Headers.GetValues("Cross-Origin-Embedder-Policy").Should().ContainSingle("require-corp");
        response.Headers.GetValues("Cross-Origin-Resource-Policy").Should().ContainSingle("same-origin");
    }
}
