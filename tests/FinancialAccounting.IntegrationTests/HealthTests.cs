using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using System.Text.RegularExpressions;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class HealthTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public HealthTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task LiveHealth_ReturnsOk()
    {
        var response = await _client.GetAsync("/health/live");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task ReadyHealth_ReturnsOk()
    {
        var response = await _client.GetAsync("/health/ready");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData("/swagger/index.html")]
    [InlineData("/swagger/v1/swagger.json")]
    public async Task SwaggerEndpoints_ReturnOkWithSecurityHeaders(string path)
    {
        using var response = await _client.GetAsync(path);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        GetRequiredHeader(response, "Content-Security-Policy")
            .Should().Contain("script-src 'self'")
            .And.Contain("style-src 'self'")
            .And.Contain("frame-ancestors 'none'")
            .And.Contain("form-action 'self'")
            .And.NotContain("'unsafe-inline'");
        GetRequiredHeader(response, "X-Frame-Options").Should().Be("DENY");
        GetRequiredHeader(response, "X-Content-Type-Options").Should().Be("nosniff");
        GetRequiredHeader(response, "Permissions-Policy").Should().NotBeNullOrWhiteSpace();
        GetRequiredHeader(response, "Cross-Origin-Opener-Policy").Should().Be("same-origin");
        GetRequiredHeader(response, "Cross-Origin-Embedder-Policy").Should().Be("require-corp");
        GetRequiredHeader(response, "Cross-Origin-Resource-Policy").Should().Be("same-origin");
    }

    [Fact]
    public async Task SwaggerIndex_UsesExternalScriptsAndStyles()
    {
        var html = await _client.GetStringAsync("/swagger/index.html");

        html.Should().NotContain("<style", "Swagger styles are loaded from external stylesheets");
        Regex.Matches(html, "<script\\b(?![^>]*\\bsrc=)[^>]*>", RegexOptions.IgnoreCase)
            .Should().BeEmpty();
    }

    [Fact]
    public async Task SwaggerBundle_UsesPatchedDomPurify()
    {
        using var response = await _client.GetAsync("/swagger/swagger-ui-bundle.js");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var bundle = await response.Content.ReadAsStringAsync();
        bundle.Should().Contain("DOMPurify.version=\"3.4.17\"");
        GetRequiredHeader(response, "X-Content-Type-Options").Should().Be("nosniff");
        GetRequiredHeader(response, "Cross-Origin-Resource-Policy").Should().Be("same-origin");
    }

    private static string GetRequiredHeader(HttpResponseMessage response, string headerName)
    {
        response.Headers.TryGetValues(headerName, out var values).Should().BeTrue();
        return values!.Single();
    }
}
