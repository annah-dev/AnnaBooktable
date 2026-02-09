using System.Net;
using System.Text.Json;
using AnnaBooktable.Shared.Models.DTOs;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace AnnaBooktable.Shared.Infrastructure.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
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
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var (statusCode, errorCode) = exception switch
        {
            ArgumentException => (HttpStatusCode.BadRequest, "BAD_REQUEST"),
            KeyNotFoundException => (HttpStatusCode.NotFound, "NOT_FOUND"),
            InvalidOperationException => (HttpStatusCode.Conflict, "CONFLICT"),
            UnauthorizedAccessException => (HttpStatusCode.Unauthorized, "UNAUTHORIZED"),
            _ => (HttpStatusCode.InternalServerError, "INTERNAL_ERROR")
        };

        _logger.LogError(exception, "Unhandled exception: {ErrorCode} - {Message}", errorCode, exception.Message);

        var response = ApiResponse<object>.Fail(exception.Message);
        context.Response.StatusCode = (int)statusCode;
        context.Response.ContentType = "application/json";

        await context.Response.WriteAsync(JsonSerializer.Serialize(response, JsonOptions));
    }
}
