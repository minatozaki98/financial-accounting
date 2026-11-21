using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public sealed class SwaggerUiTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public SwaggerUiTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task SwaggerUiAndDocument_RenderOperationsWithSecurityHeaders()
    {
        using var htmlResponse = await _client.GetAsync("/swagger/index.html");
        htmlResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        htmlResponse.Headers.GetValues("Content-Security-Policy").Single().Should().Contain("form-action 'self'");
        htmlResponse.Headers.GetValues("X-Content-Type-Options").Single().Should().Be("nosniff");
        htmlResponse.Headers.GetValues("Cross-Origin-Resource-Policy").Single().Should().Be("same-origin");

        var html = await htmlResponse.Content.ReadAsStringAsync();
        html.Should().Contain("swagger-ui-bundle.js");

        using var bundleResponse = await _client.GetAsync("/swagger/swagger-ui-bundle.js");
        bundleResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        var bundle = await bundleResponse.Content.ReadAsStringAsync();
        bundle.Should().Contain("SwaggerUIBundle");

        using var documentResponse = await _client.GetAsync("/swagger/v1/swagger.json");
        documentResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        documentResponse.Headers.GetValues("X-Content-Type-Options").Single().Should().Be("nosniff");
        documentResponse.Headers.GetValues("Cross-Origin-Resource-Policy").Single().Should().Be("same-origin");

        using var document = JsonDocument.Parse(await documentResponse.Content.ReadAsStringAsync());
        document.RootElement.GetProperty("paths").EnumerateObject().Should().NotBeEmpty();
        document.RootElement.GetProperty("components").GetProperty("securitySchemes").GetProperty("Bearer").GetProperty("scheme").GetString().Should().Be("bearer");
    }
}
