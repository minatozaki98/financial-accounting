using FinancialAccounting.IntegrationTests.Fixtures;
using FluentAssertions;
using System.Net;
using System.Text.Json;
using Xunit;

namespace FinancialAccounting.IntegrationTests;

public class SwaggerSecurityHeadersTests : IClassFixture<TestApiFactory>
{
    private readonly HttpClient _client;

    public SwaggerSecurityHeadersTests(TestApiFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task SwaggerUi_ReturnsSecurityHeadersWithoutBlockingSameOriginAssets()
    {
        using var response = await _client.GetAsync("/swagger/index.html");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.TryGetValues("Content-Security-Policy", out var contentSecurityPolicies).Should().BeTrue();
        var contentSecurityPolicy = contentSecurityPolicies.Should().ContainSingle().Which;
        contentSecurityPolicy.Should().Contain("form-action 'self'");
        contentSecurityPolicy.Should().NotContain("'unsafe-inline'");
        response.Headers.TryGetValues("X-Frame-Options", out var frameOptions).Should().BeTrue();
        frameOptions.Should().ContainSingle("DENY");
        response.Headers.TryGetValues("X-Content-Type-Options", out var contentTypeOptions).Should().BeTrue();
        contentTypeOptions.Should().ContainSingle("nosniff");

        var html = await response.Content.ReadAsStringAsync();
        html.Should().Contain("swagger-ui-bundle.js");
        html.Should().Contain("index.js");

        using var documentResponse = await _client.GetAsync("/swagger/v1/swagger.json");
        documentResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        documentResponse.Headers.TryGetValues("X-Content-Type-Options", out var documentContentTypeOptions).Should().BeTrue();
        documentContentTypeOptions.Should().ContainSingle("nosniff");

        var document = await documentResponse.Content.ReadAsStringAsync();
        document.Should().Contain("securitySchemes");
        document.Should().Contain("Bearer");

        using var openApiDocument = JsonDocument.Parse(document);
        var operationCount = openApiDocument.RootElement
            .GetProperty("paths")
            .EnumerateObject()
            .Sum(path => path.Value.EnumerateObject().Count(operation => operation.Name is "get" or "put" or "post" or "delete" or "patch" or "options" or "head"));
        operationCount.Should().Be(23);
    }

    [Fact]
    public async Task SwaggerUiBundle_UsesPatchedDomPurify()
    {
        using var response = await _client.GetAsync("/swagger/swagger-ui-bundle.js");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var bundle = await response.Content.ReadAsStringAsync();
        bundle.Contains("DOMPurify.version=\"3.4.17\"", StringComparison.Ordinal).Should().BeTrue();
    }
}
