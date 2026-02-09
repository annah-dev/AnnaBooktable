using System.Text.Json;
using AnnaBooktable.Shared.Events;
using AnnaBooktable.Shared.Infrastructure.Data;
using AnnaBooktable.Shared.Infrastructure.Extensions;
using AnnaBooktable.Shared.Infrastructure.Redis;
using AnnaBooktable.Shared.Models.DTOs;
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

    // MassTransit
    builder.Services.AddMassTransit(x =>
    {
        x.UsingRabbitMq((context, cfg) =>
        {
            cfg.Host(new Uri(builder.Configuration.GetConnectionString("RabbitMQ")!));
            cfg.ConfigureEndpoints(context);
        });
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

    var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    // ==========================================================
    // GET /api/inventory/availability
    // Check Redis cache first, fallback to PostgreSQL
    // ==========================================================
    app.MapGet("/api/inventory/availability", async (
        Guid restaurantId,
        DateOnly date,
        int? partySize,
        Guid? tableGroupId,
        BooktableDbContext db,
        RedisService redis) =>
    {
        var minCapacity = partySize ?? 1;

        // Try Redis cache first
        var cached = await redis.GetCachedAvailability(restaurantId, date);
        if (cached != null)
        {
            var cachedResponse = JsonSerializer.Deserialize<AvailabilityResponse>(cached, jsonOptions);
            if (cachedResponse != null)
            {
                // Filter cached results by party size
                cachedResponse.Slots = cachedResponse.Slots
                    .Where(s => s.Capacity >= minCapacity)
                    .ToArray();
                return Results.Ok(ApiResponse<AvailabilityResponse>.Ok(cachedResponse));
            }
        }

        // Fallback to PostgreSQL
        var query = db.TimeSlots
            .Where(ts => ts.RestaurantId == restaurantId
                && ts.Date == date
                && ts.Status == "AVAILABLE"
                && ts.Capacity >= minCapacity);

        if (tableGroupId.HasValue)
            query = query.Where(ts => ts.TableGroupId == tableGroupId.Value);

        var slots = await query
            .Join(db.Tables,
                ts => ts.TableId,
                t => t.TableId,
                (ts, t) => new { TimeSlot = ts, Table = t })
            .GroupJoin(db.TableGroups,
                x => x.TimeSlot.TableGroupId,
                tg => tg.TableGroupId,
                (x, tgs) => new { x.TimeSlot, x.Table, TableGroup = tgs.FirstOrDefault() })
            .OrderBy(x => x.TimeSlot.StartTime)
            .Select(x => new AvailableSlotDetail
            {
                SlotId = x.TimeSlot.SlotId,
                StartTime = x.TimeSlot.StartTime,
                EndTime = x.TimeSlot.EndTime,
                TableNumber = x.Table.TableNumber,
                TableGroupName = x.TableGroup != null ? x.TableGroup.Name : null,
                Capacity = x.TimeSlot.Capacity
            })
            .ToListAsync();

        var response = new AvailabilityResponse
        {
            RestaurantId = restaurantId,
            Date = date,
            Slots = slots.ToArray()
        };

        // Cache for 60 seconds
        var responseJson = JsonSerializer.Serialize(response, jsonOptions);
        await redis.SetCachedAvailability(restaurantId, date, responseJson, 60);

        return Results.Ok(ApiResponse<AvailabilityResponse>.Ok(response));
    })
    .WithName("GetAvailability")
    .WithOpenApi();

    // ==========================================================
    // POST /api/inventory/hold - LAYER 1: Redis SETNX hold
    // ==========================================================
    app.MapPost("/api/inventory/hold", async (
        HoldRequest request,
        RedisService redis,
        IPublishEndpoint publishEndpoint,
        ILogger<Program> logger) =>
    {
        var (success, holdToken) = await redis.TryAcquireHold(request.SlotId, request.UserId, 300);

        if (!success)
        {
            return Results.Conflict(ApiResponse<object>.Fail("Slot already held by another diner"));
        }

        var expiresAt = DateTime.UtcNow.AddSeconds(300);

        // Publish SlotHeld event
        try
        {
            await publishEndpoint.Publish(new SlotHeld
            {
                SlotId = request.SlotId,
                UserId = request.UserId,
                ExpiresAt = expiresAt
            });
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to publish SlotHeld event for slot {SlotId}", request.SlotId);
        }

        var response = new HoldResponse
        {
            HoldToken = holdToken,
            ExpiresAt = expiresAt,
            SlotId = request.SlotId
        };

        return Results.Ok(ApiResponse<HoldResponse>.Ok(response));
    })
    .WithName("AcquireHold")
    .WithOpenApi();

    // ==========================================================
    // DELETE /api/inventory/hold/{slotId} - Release hold early
    // ==========================================================
    app.MapDelete("/api/inventory/hold/{slotId:guid}", async (
        Guid slotId,
        RedisService redis,
        IPublishEndpoint publishEndpoint,
        ILogger<Program> logger) =>
    {
        await redis.ReleaseHold(slotId);

        try
        {
            await publishEndpoint.Publish(new SlotReleased
            {
                SlotId = slotId,
                Reason = "Released by user"
            });
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to publish SlotReleased event for slot {SlotId}", slotId);
        }

        return Results.Ok(ApiResponse<object>.Ok(new { Message = "Hold released" }));
    })
    .WithName("ReleaseHold")
    .WithOpenApi();

    // ==========================================================
    // GET /api/inventory/hold/{slotId}/validate - Validate hold
    // ==========================================================
    app.MapGet("/api/inventory/hold/{slotId:guid}/validate", async (
        Guid slotId,
        string holdToken,
        RedisService redis) =>
    {
        var isValid = await redis.ValidateHold(slotId, holdToken);

        return Results.Ok(ApiResponse<object>.Ok(new { Valid = isValid }));
    })
    .WithName("ValidateHold")
    .WithOpenApi();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "InventoryService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
