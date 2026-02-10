using System.Net.Http.Json;
using System.Text.Json;
using AnnaBooktable.Shared.Events;
using AnnaBooktable.Shared.Infrastructure.Data;
using AnnaBooktable.Shared.Infrastructure.Extensions;
using AnnaBooktable.Shared.Infrastructure.Redis;
using AnnaBooktable.Shared.Models.DTOs;
using AnnaBooktable.Shared.Models.Entities;
using MassTransit;
using Microsoft.EntityFrameworkCore;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((context, config) =>
        config.ReadFrom.Configuration(context.Configuration));

    // Infrastructure
    builder.Services.AddBooktableDbContext(
        builder.Configuration.GetConnectionString("PostgreSQL")!);
    builder.Services.AddRedisService(
        builder.Configuration.GetConnectionString("Redis")!);

    // HTTP clients for inter-service calls
    var inventoryUrl = builder.Configuration["ServiceUrls:Inventory"] ?? "http://localhost:5002";
    var paymentUrl = builder.Configuration["ServiceUrls:Payments"] ?? "http://localhost:5004";
    builder.Services.AddHttpClient("InventoryService", client =>
    {
        client.BaseAddress = new Uri(inventoryUrl);
    });
    builder.Services.AddHttpClient("PaymentService", client =>
    {
        client.BaseAddress = new Uri(paymentUrl);
    });

    // MassTransit - use RabbitMQ if configured, otherwise in-memory
    var rabbitMqConn = builder.Configuration.GetConnectionString("RabbitMQ");
    builder.Services.AddMassTransit(x =>
    {
        if (!string.IsNullOrEmpty(rabbitMqConn))
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

    var jsonOptions = new JsonSerializerOptions
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    // ==========================================================
    // POST /api/reservations - THE CRITICAL PATH
    // Layer 1: Hold validation (Redis via InventoryService)
    // Layer 2: DB unique constraint (prevents double-booking)
    // Layer 3: Idempotency key (Redis)
    // ==========================================================
    app.MapPost("/api/reservations", async (
        BookingRequest request,
        HttpContext httpContext,
        BooktableDbContext db,
        RedisService redis,
        IHttpClientFactory httpClientFactory,
        IPublishEndpoint publishEndpoint,
        ILogger<Program> logger) =>
    {
        // Get idempotency key from header or request body
        var idempotencyKey = httpContext.Request.Headers["Idempotency-Key"].FirstOrDefault()
            ?? request.IdempotencyKey;

        // ── LAYER 3: Check idempotency key ──────────────────
        if (!string.IsNullOrEmpty(idempotencyKey))
        {
            var cachedResponse = await redis.CheckIdempotencyKey(idempotencyKey);
            if (cachedResponse != null)
            {
                logger.LogInformation("Idempotency hit for key {Key}", idempotencyKey);
                var cached = JsonSerializer.Deserialize<BookingResponse>(cachedResponse, jsonOptions);
                return Results.Ok(ApiResponse<BookingResponse>.Ok(cached!));
            }
        }

        // ── Validate hold with InventoryService ─────────────
        if (!string.IsNullOrEmpty(request.HoldToken))
        {
            try
            {
                var inventoryClient = httpClientFactory.CreateClient("InventoryService");
                var validateUrl = $"/api/inventory/hold/{request.SlotId}/validate?holdToken={request.HoldToken}";
                var validateResponse = await inventoryClient.GetFromJsonAsync<ApiResponse<JsonElement>>(validateUrl, jsonOptions);

                if (validateResponse?.Data.GetProperty("valid").GetBoolean() != true)
                {
                    return Results.Conflict(ApiResponse<object>.Fail("Hold is no longer valid. Please try again."));
                }
            }
            catch (Exception ex)
            {
                // Graceful degradation - if inventory service is down, proceed without hold validation
                logger.LogWarning(ex, "Could not validate hold for slot {SlotId}, proceeding without validation", request.SlotId);
            }
        }

        // ── Call PaymentService to charge deposit ───────────
        string? paymentIntentId = null;
        decimal depositAmount = 0;
        string paymentStatus = "NONE";

        if (!string.IsNullOrEmpty(request.PaymentToken))
        {
            try
            {
                var paymentClient = httpClientFactory.CreateClient("PaymentService");
                depositAmount = 25.00m; // Standard deposit amount
                var chargePayload = new
                {
                    Amount = depositAmount,
                    Currency = "usd",
                    PaymentToken = request.PaymentToken,
                    IdempotencyKey = idempotencyKey,
                    Description = $"Deposit for reservation at slot {request.SlotId}"
                };

                var chargeResponse = await paymentClient.PostAsJsonAsync("/api/payments/charge", chargePayload, jsonOptions);
                chargeResponse.EnsureSuccessStatusCode();

                var chargeResult = await chargeResponse.Content.ReadFromJsonAsync<ApiResponse<JsonElement>>(jsonOptions);
                paymentIntentId = chargeResult?.Data.GetProperty("paymentIntentId").GetString();
                paymentStatus = "CAPTURED";
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Payment failed for slot {SlotId}", request.SlotId);
                return Results.UnprocessableEntity(ApiResponse<object>.Fail("Payment processing failed"));
            }
        }

        // ── LAYER 2: Database transaction with unique constraint ──
        var confirmationCode = GenerateConfirmationCode();

        // Look up the slot to get restaurant_id
        var slot = await db.TimeSlots
            .Where(ts => ts.SlotId == request.SlotId)
            .FirstOrDefaultAsync();

        if (slot == null)
        {
            // Refund if we already charged
            if (paymentIntentId != null)
                await TryRefund(httpClientFactory, paymentIntentId, depositAmount, jsonOptions, logger);
            return Results.NotFound(ApiResponse<object>.Fail("Time slot not found"));
        }

        await using var transaction = await db.Database.BeginTransactionAsync();
        try
        {
            var reservation = new Reservation
            {
                ReservationId = Guid.NewGuid(),
                UserId = request.UserId,
                RestaurantId = slot.RestaurantId,
                SlotId = request.SlotId,
                ConfirmationCode = confirmationCode,
                PartySize = request.PartySize,
                SpecialRequests = request.SpecialRequests,
                Status = "CONFIRMED",
                DepositAmount = depositAmount,
                PaymentStatus = paymentStatus,
                PaymentIntentId = paymentIntentId,
                IdempotencyKey = idempotencyKey,
                BookedAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            db.Reservations.Add(reservation);

            // Update time slot status to BOOKED
            slot.Status = "BOOKED";
            slot.HeldBy = null;
            slot.HeldUntil = null;

            await db.SaveChangesAsync();
            await transaction.CommitAsync();

            // ── Build response ──────────────────────────────
            var restaurant = await db.Restaurants
                .Where(r => r.RestaurantId == slot.RestaurantId)
                .Select(r => r.Name)
                .FirstOrDefaultAsync();

            var bookingResponse = new BookingResponse
            {
                ReservationId = reservation.ReservationId,
                ConfirmationCode = confirmationCode,
                Status = reservation.Status,
                RestaurantName = restaurant ?? "Unknown",
                DateTime = slot.StartTime,
                PartySize = request.PartySize
            };

            // ── LAYER 3: Cache idempotency response (24hr TTL) ──
            if (!string.IsNullOrEmpty(idempotencyKey))
            {
                var responseJson = JsonSerializer.Serialize(bookingResponse, jsonOptions);
                await redis.SetIdempotencyKey(idempotencyKey, responseJson, 86400);
            }

            // Release hold in Redis (cleanup)
            await redis.ReleaseHold(request.SlotId);

            // Invalidate availability cache so the booked slot disappears immediately
            await redis.InvalidateCachedAvailability(slot.RestaurantId, DateOnly.FromDateTime(slot.StartTime));

            // Publish ReservationCreated event
            try
            {
                await publishEndpoint.Publish(new ReservationCreated
                {
                    ReservationId = reservation.ReservationId,
                    UserId = request.UserId,
                    RestaurantId = slot.RestaurantId,
                    SlotId = request.SlotId,
                    ConfirmationCode = confirmationCode,
                    DateTime = slot.StartTime,
                    PartySize = request.PartySize
                });
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to publish ReservationCreated event");
            }

            return Results.Ok(ApiResponse<BookingResponse>.Ok(bookingResponse));
        }
        catch (DbUpdateException ex) when (IsUniqueConstraintViolation(ex))
        {
            await transaction.RollbackAsync();

            // Refund payment on double-booking
            if (paymentIntentId != null)
                await TryRefund(httpClientFactory, paymentIntentId, depositAmount, jsonOptions, logger);

            logger.LogWarning("Double-booking prevented by DB constraint for slot {SlotId}", request.SlotId);
            return Results.Conflict(ApiResponse<object>.Fail("This time slot has already been booked"));
        }
    })
    .WithName("CreateReservation")
    .WithOpenApi();

    // ==========================================================
    // GET /api/reservations/{id} - Get reservation detail
    // ==========================================================
    app.MapGet("/api/reservations/{id:guid}", async (
        Guid id,
        BooktableDbContext db) =>
    {
        var reservation = await db.Reservations
            .Where(r => r.ReservationId == id)
            .Join(db.Restaurants,
                r => r.RestaurantId,
                rest => rest.RestaurantId,
                (r, rest) => new { Reservation = r, RestaurantName = rest.Name })
            .FirstOrDefaultAsync();

        if (reservation is null)
            return Results.NotFound(ApiResponse<object>.Fail("Reservation not found"));

        var slot = await db.TimeSlots
            .Where(ts => ts.SlotId == reservation.Reservation.SlotId)
            .FirstOrDefaultAsync();

        var response = new BookingResponse
        {
            ReservationId = reservation.Reservation.ReservationId,
            ConfirmationCode = reservation.Reservation.ConfirmationCode,
            Status = reservation.Reservation.Status,
            RestaurantName = reservation.RestaurantName,
            DateTime = slot?.StartTime ?? reservation.Reservation.BookedAt,
            PartySize = reservation.Reservation.PartySize
        };

        return Results.Ok(ApiResponse<BookingResponse>.Ok(response));
    })
    .WithName("GetReservation")
    .WithOpenApi();

    // ==========================================================
    // GET /api/reservations/user/{userId} - User's reservations
    // ==========================================================
    app.MapGet("/api/reservations/user/{userId:guid}", async (
        Guid userId,
        BooktableDbContext db) =>
    {
        var reservations = await db.Reservations
            .Where(r => r.UserId == userId)
            .Join(db.Restaurants,
                r => r.RestaurantId,
                rest => rest.RestaurantId,
                (r, rest) => new { Reservation = r, RestaurantName = rest.Name, Cuisine = rest.Cuisine })
            .GroupJoin(db.TimeSlots,
                x => x.Reservation.SlotId,
                ts => ts.SlotId,
                (x, slots) => new { x.Reservation, x.RestaurantName, x.Cuisine, Slot = slots.FirstOrDefault() })
            .Select(x => new BookingResponse
            {
                ReservationId = x.Reservation.ReservationId,
                ConfirmationCode = x.Reservation.ConfirmationCode,
                Status = x.Reservation.Status,
                RestaurantName = x.RestaurantName,
                Cuisine = x.Cuisine,
                DateTime = x.Slot != null ? x.Slot.StartTime : x.Reservation.BookedAt,
                PartySize = x.Reservation.PartySize
            })
            .OrderByDescending(r => r.DateTime)
            .ToListAsync();

        return Results.Ok(ApiResponse<List<BookingResponse>>.Ok(reservations));
    })
    .WithName("GetUserReservations")
    .WithOpenApi();

    // ==========================================================
    // POST /api/reservations/{id}/cancel - Cancel reservation
    // ==========================================================
    app.MapPost("/api/reservations/{id:guid}/cancel", async (
        Guid id,
        BooktableDbContext db,
        RedisService redis,
        IHttpClientFactory httpClientFactory,
        IPublishEndpoint publishEndpoint,
        ILogger<Program> logger) =>
    {
        var reservation = await db.Reservations
            .FirstOrDefaultAsync(r => r.ReservationId == id);

        if (reservation is null)
            return Results.NotFound(ApiResponse<object>.Fail("Reservation not found"));

        if (reservation.Status == "CANCELLED")
            return Results.Ok(ApiResponse<object>.Ok(new { Message = "Already cancelled" }));

        // Update reservation status
        reservation.Status = "CANCELLED";
        reservation.UpdatedAt = DateTime.UtcNow;

        // Release the time slot back to AVAILABLE
        var slot = await db.TimeSlots
            .Where(ts => ts.SlotId == reservation.SlotId)
            .FirstOrDefaultAsync();

        if (slot != null)
        {
            slot.Status = "AVAILABLE";
            slot.HeldBy = null;
            slot.HeldUntil = null;
        }

        await db.SaveChangesAsync();

        // Invalidate availability cache so the freed slot appears immediately
        if (slot != null)
            await redis.InvalidateCachedAvailability(reservation.RestaurantId, DateOnly.FromDateTime(slot.StartTime));

        // Refund if payment was captured
        if (reservation.PaymentStatus == "CAPTURED" && reservation.PaymentIntentId != null)
        {
            await TryRefund(httpClientFactory, reservation.PaymentIntentId,
                reservation.DepositAmount, jsonOptions, logger);
            reservation.PaymentStatus = "REFUNDED";
            await db.SaveChangesAsync();
        }

        // Publish cancellation event
        try
        {
            await publishEndpoint.Publish(new ReservationCancelled
            {
                ReservationId = reservation.ReservationId,
                UserId = reservation.UserId,
                RestaurantId = reservation.RestaurantId,
                SlotId = reservation.SlotId,
                Reason = "Cancelled by user"
            });
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to publish ReservationCancelled event");
        }

        return Results.Ok(ApiResponse<object>.Ok(new { Message = "Reservation cancelled" }));
    })
    .WithName("CancelReservation")
    .WithOpenApi();

    // ==========================================================
    // GET /api/reservations/confirm/{confirmationCode} - Lookup
    // ==========================================================
    app.MapGet("/api/reservations/confirm/{confirmationCode}", async (
        string confirmationCode,
        BooktableDbContext db) =>
    {
        var reservation = await db.Reservations
            .Where(r => r.ConfirmationCode == confirmationCode)
            .Join(db.Restaurants,
                r => r.RestaurantId,
                rest => rest.RestaurantId,
                (r, rest) => new { Reservation = r, RestaurantName = rest.Name })
            .FirstOrDefaultAsync();

        if (reservation is null)
            return Results.NotFound(ApiResponse<object>.Fail("Reservation not found"));

        var slot = await db.TimeSlots
            .Where(ts => ts.SlotId == reservation.Reservation.SlotId)
            .FirstOrDefaultAsync();

        var response = new BookingResponse
        {
            ReservationId = reservation.Reservation.ReservationId,
            ConfirmationCode = reservation.Reservation.ConfirmationCode,
            Status = reservation.Reservation.Status,
            RestaurantName = reservation.RestaurantName,
            DateTime = slot?.StartTime ?? reservation.Reservation.BookedAt,
            PartySize = reservation.Reservation.PartySize
        };

        return Results.Ok(ApiResponse<BookingResponse>.Ok(response));
    })
    .WithName("LookupByConfirmationCode")
    .WithOpenApi();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "ReservationService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// ==========================================================
// Helper methods
// ==========================================================
static string GenerateConfirmationCode()
{
    const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I,O,0,1
    var random = Random.Shared;
    return new string(Enumerable.Range(0, 6).Select(_ => chars[random.Next(chars.Length)]).ToArray());
}

static bool IsUniqueConstraintViolation(DbUpdateException ex)
{
    // Npgsql unique violation error code: 23505
    return ex.InnerException?.Message.Contains("23505") == true
        || ex.InnerException?.Message.Contains("unique constraint") == true
        || ex.InnerException?.Message.Contains("duplicate key") == true;
}

static async Task TryRefund(
    IHttpClientFactory httpClientFactory,
    string paymentIntentId,
    decimal amount,
    JsonSerializerOptions jsonOptions,
    Microsoft.Extensions.Logging.ILogger<Program> logger)
{
    try
    {
        var paymentClient = httpClientFactory.CreateClient("PaymentService");
        await paymentClient.PostAsJsonAsync("/api/payments/refund",
            new { PaymentIntentId = paymentIntentId, Amount = amount }, jsonOptions);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to refund payment {PaymentIntentId}", paymentIntentId);
    }
}
