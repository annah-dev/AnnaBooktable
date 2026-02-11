using AnnaBooktable.Shared.Infrastructure.Extensions;
using AnnaBooktable.Shared.Models.DTOs;
using MassTransit;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((context, config) =>
        config.ReadFrom.Configuration(context.Configuration));

    // MassTransit - Azure Service Bus → RabbitMQ → InMemory
    var sbConn = builder.Configuration.GetConnectionString("AzureServiceBus");
    var rabbitMqConn = builder.Configuration.GetConnectionString("RabbitMQ");
    builder.Services.AddMassTransit(x =>
    {
        if (!string.IsNullOrEmpty(sbConn))
        {
            x.UsingAzureServiceBus((context, cfg) =>
            {
                cfg.Host(sbConn);
                cfg.ConfigureEndpoints(context);
            });
        }
        else if (!string.IsNullOrEmpty(rabbitMqConn))
        {
            x.UsingRabbitMq((context, cfg) =>
            {
                cfg.Host(new Uri(rabbitMqConn));
                cfg.ConfigureEndpoints(context);
            });
        }
        else
        {
            x.UsingInMemory((context, cfg) => cfg.ConfigureEndpoints(context));
        }
    });

    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();

    var app = builder.Build();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseBooktableMiddleware();

    // ==========================================================
    // POST /api/payments/charge - Simulate Stripe charge
    // Always succeeds in dev mode with fake payment_intent_id
    // ==========================================================
    app.MapPost("/api/payments/charge", (
        ChargeRequest request,
        ILogger<Program> logger) =>
    {
        var paymentIntentId = $"pi_dev_{Guid.NewGuid():N}";

        logger.LogInformation(
            "DEV MODE: Simulated charge of {Amount} {Currency}, PaymentIntent {PaymentIntentId}",
            request.Amount, request.Currency, paymentIntentId);

        var response = new ChargeResponse
        {
            PaymentIntentId = paymentIntentId,
            Status = "captured",
            Amount = request.Amount
        };

        return Results.Ok(ApiResponse<ChargeResponse>.Ok(response));
    })
    .WithName("Charge")
    .WithOpenApi();

    // ==========================================================
    // POST /api/payments/refund - Simulate Stripe refund
    // Always succeeds in dev mode
    // ==========================================================
    app.MapPost("/api/payments/refund", (
        RefundRequest request,
        ILogger<Program> logger) =>
    {
        var refundId = $"re_dev_{Guid.NewGuid():N}";

        logger.LogInformation(
            "DEV MODE: Simulated refund of {Amount} for PaymentIntent {PaymentIntentId}, Refund {RefundId}",
            request.Amount, request.PaymentIntentId, refundId);

        var response = new RefundResponse
        {
            RefundId = refundId,
            Status = "refunded"
        };

        return Results.Ok(ApiResponse<RefundResponse>.Ok(response));
    })
    .WithName("Refund")
    .WithOpenApi();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "PaymentService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// ==========================================================
// Request/Response models local to PaymentService
// ==========================================================
public class ChargeRequest
{
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "usd";
    public string? PaymentToken { get; set; }
    public string? IdempotencyKey { get; set; }
    public string? Description { get; set; }
}

public class ChargeResponse
{
    public string PaymentIntentId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public decimal Amount { get; set; }
}

public class RefundRequest
{
    public string PaymentIntentId { get; set; } = string.Empty;
    public decimal? Amount { get; set; }
}

public class RefundResponse
{
    public string RefundId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
