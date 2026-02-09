using System.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace AnnaBooktable.Shared.Infrastructure.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = context.Request.Headers["X-Correlation-Id"].FirstOrDefault()
            ?? Guid.NewGuid().ToString("N");

        context.Response.Headers["X-Correlation-Id"] = correlationId;

        var stopwatch = Stopwatch.StartNew();

        using (_logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId }))
        {
            _logger.LogInformation("HTTP {Method} {Path} started",
                context.Request.Method, context.Request.Path);

            await _next(context);

            stopwatch.Stop();

            _logger.LogInformation("HTTP {Method} {Path} responded {StatusCode} in {ElapsedMs}ms",
                context.Request.Method, context.Request.Path,
                context.Response.StatusCode, stopwatch.ElapsedMilliseconds);
        }
    }
}
