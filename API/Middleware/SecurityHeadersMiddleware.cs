using Microsoft.Extensions.Options;
using MODEL.ApplicationConfig;

namespace API.Middleware
{
    public sealed class SecurityHeadersMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly SecurityHeadersOptions _options;

        public SecurityHeadersMiddleware(RequestDelegate next, IOptions<AppSettings> appSettings)
        {
            _next = next;
            _options = appSettings.Value.SecurityHeaders;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            if (_options.Enabled)
            {
                context.Response.OnStarting(() =>
                {
                    SetHeaderIfMissing(context, "Content-Security-Policy", GetContentSecurityPolicy(context.Request.Path));
                    SetHeaderIfMissing(context, "X-Frame-Options", _options.XFrameOptions);
                    SetHeaderIfMissing(context, "X-Content-Type-Options", _options.XContentTypeOptions);
                    SetHeaderIfMissing(context, "Permissions-Policy", _options.PermissionsPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Opener-Policy", _options.CrossOriginOpenerPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Embedder-Policy", _options.CrossOriginEmbedderPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Resource-Policy", _options.CrossOriginResourcePolicy);
                    SetHeaderIfMissing(context, "Referrer-Policy", _options.ReferrerPolicy);
                    SetHeaderIfMissing(context, "Cache-Control", _options.CacheControl);
                    SetHeaderIfMissing(context, "Pragma", _options.Pragma);

                    if (context.Request.IsHttps)
                    {
                        SetHeaderIfMissing(context, "Strict-Transport-Security", _options.StrictTransportSecurity);
                    }

                    return Task.CompletedTask;
                });
            }

            await _next(context);
        }

        private string GetContentSecurityPolicy(PathString requestPath)
        {
            return IsSwaggerUiRequest(requestPath)
                ? _options.SwaggerContentSecurityPolicy
                : _options.ContentSecurityPolicy;
        }

        private static bool IsSwaggerUiRequest(PathString requestPath)
        {
            if (!requestPath.StartsWithSegments("/swagger", out var remainingPath))
            {
                return false;
            }

            return remainingPath == PathString.Empty
                || remainingPath == "/"
                || remainingPath == "/index.html"
                || remainingPath.Value?.EndsWith(".js", StringComparison.OrdinalIgnoreCase) == true
                || remainingPath.Value?.EndsWith(".css", StringComparison.OrdinalIgnoreCase) == true
                || remainingPath.Value?.EndsWith(".png", StringComparison.OrdinalIgnoreCase) == true;
        }

        private static void SetHeaderIfMissing(HttpContext context, string headerName, string headerValue)
        {
            if (!string.IsNullOrWhiteSpace(headerValue) && !context.Response.Headers.ContainsKey(headerName))
            {
                context.Response.Headers[headerName] = headerValue;
            }
        }
    }
}
