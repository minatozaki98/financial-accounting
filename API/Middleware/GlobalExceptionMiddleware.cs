using Microsoft.AspNetCore.Mvc;

namespace API.Middleware
{
    public sealed class GlobalExceptionMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<GlobalExceptionMiddleware> _logger;

        public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (InvalidOperationException ex)
            {
                await WriteProblemAsync(context, StatusCodes.Status400BadRequest, "Invalid operation", ex.Message, ex);
            }
            catch (KeyNotFoundException ex)
            {
                await WriteProblemAsync(context, StatusCodes.Status404NotFound, "Resource not found", ex.Message, ex);
            }
            catch (UnauthorizedAccessException ex)
            {
                await WriteProblemAsync(context, StatusCodes.Status403Forbidden, "Forbidden", ex.Message, ex);
            }
            catch (Exception ex)
            {
                await WriteProblemAsync(context, StatusCodes.Status500InternalServerError, "Unexpected server error", "An unexpected error occurred.", ex);
            }
        }

        private async Task WriteProblemAsync(HttpContext context, int statusCode, string title, string detail, Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception. CorrelationId={CorrelationId}", context.TraceIdentifier);

            var problem = new ProblemDetails
            {
                Status = statusCode,
                Title = title,
                Detail = detail,
                Instance = context.Request.Path
            };

            problem.Extensions["correlationId"] = context.TraceIdentifier;

            context.Response.StatusCode = statusCode;
            context.Response.ContentType = "application/problem+json";
            await context.Response.WriteAsJsonAsync(problem);
        }
    }
}
