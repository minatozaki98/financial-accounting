using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class SecurityHeadersTests : IClassFixture<TestApiFactory>
{
    private const string DefaultContentSecurityPolicy = "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none';";
    private readonly HttpClient _client;
    private readonly TestApiFactory _factory;

    public SecurityHeadersTests(TestApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Theory]
    [InlineData("/swagger/v1/swagger.json", "Content-Security-Policy", DefaultContentSecurityPolicy)]
    [InlineData("/swagger/v1/swagger.json", "Cross-Origin-Embedder-Policy", "require-corp")]
    [InlineData("/swagger/v1/swagger.json", "Cross-Origin-Opener-Policy", "same-origin")]
    [InlineData("/swagger/v1/swagger.json", "Permissions-Policy", "camera=(), microphone=(), geolocation=()")]
    [InlineData("/swagger/v1/swagger.json", "Cross-Origin-Resource-Policy", "same-origin")]
    [InlineData("/swagger/v1/swagger.json", "X-Content-Type-Options", "nosniff")]
    public async Task SwaggerDocumentResponses_IncludeExpectedSecurityHeaders(string path, string headerName, string expectedValue)
    {
        using var response = await _client.GetAsync(path);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.TryGetValues(headerName, out var values).Should().BeTrue();
        values.Should().ContainSingle().Which.Should().Be(expectedValue);
    }

    [Fact]
    public async Task Root_RedirectsToOpenApiDocument_WhenSwaggerUiIsDisabled()
    {
        using var redirectClient = _factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        using var response = await redirectClient.GetAsync("/", HttpCompletionOption.ResponseHeadersRead);

        response.StatusCode.Should().Be(HttpStatusCode.Redirect);
        response.Headers.Location.Should().NotBeNull();
        response.Headers.Location!.ToString().Should().Be("/swagger/v1/swagger.json");
    }
}
