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
                    SetHeaderIfMissing(context, "Content-Security-Policy", _options.ContentSecurityPolicy);
                    SetHeaderIfMissing(context, "X-Frame-Options", _options.XFrameOptions);
                    SetHeaderIfMissing(context, "X-Content-Type-Options", _options.XContentTypeOptions);
                    SetHeaderIfMissing(context, "Permissions-Policy", _options.PermissionsPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Opener-Policy", _options.CrossOriginOpenerPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Embedder-Policy", _options.CrossOriginEmbedderPolicy);
                    SetHeaderIfMissing(context, "Cross-Origin-Resource-Policy", _options.CrossOriginResourcePolicy);
                    return Task.CompletedTask;
                });
            }

            await _next(context);
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
