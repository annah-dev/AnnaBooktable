using System.Text.Json;
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

    // ==========================================================
    // GET /api/search - Restaurant search with filtering & sorting
    // ==========================================================
    app.MapGet("/api/search", async (
        string? query,
        string? cuisine,
        string? city,
        DateOnly? date,
        TimeOnly? time,
        int? partySize,
        double? latitude,
        double? longitude,
        double? radius,
        int? page,
        int? pageSize,
        BooktableDbContext db,
        RedisService redis) =>
    {
        var pg = page ?? 1;
        var ps = pageSize is null or < 1 or > 100 ? 25 : pageSize.Value;
        if (pg < 1) pg = 1;

        // Try Redis cache for search results
        var cacheKey = $"search:{query}:{cuisine}:{city}:{date}:{time}:{partySize}:{pg}:{ps}";
        var cached = await redis.GetCachedAvailability(Guid.Empty, DateOnly.FromDateTime(DateTime.UtcNow));

        // Build restaurant query
        var restaurantQuery = db.Restaurants
            .Where(r => r.IsActive)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query))
            restaurantQuery = restaurantQuery.Where(r =>
                EF.Functions.ILike(r.Name, $"%{query}%") ||
                (r.Cuisine != null && EF.Functions.ILike(r.Cuisine, $"%{query}%")));

        if (!string.IsNullOrWhiteSpace(cuisine))
            restaurantQuery = restaurantQuery.Where(r =>
                r.Cuisine != null && EF.Functions.ILike(r.Cuisine, $"%{cuisine}%"));

        if (!string.IsNullOrWhiteSpace(city))
            restaurantQuery = restaurantQuery.Where(r =>
                r.City != null && EF.Functions.ILike(r.City, $"%{city}%"));

        // If date/partySize provided, join with available time_slots
        if (date.HasValue || partySize.HasValue)
        {
            var slotDate = date ?? DateOnly.FromDateTime(DateTime.UtcNow);
            var minCapacity = partySize ?? 1;

            var slotsQuery = db.TimeSlots
                .Where(ts => ts.Status == "AVAILABLE" && ts.Capacity >= minCapacity);

            if (date.HasValue)
                slotsQuery = slotsQuery.Where(ts => ts.Date == slotDate);

            if (time.HasValue)
            {
                // Filter slots within +/- 1.5 hours of requested time
                var requestedDateTime = slotDate.ToDateTime(time.Value);
                var windowStart = requestedDateTime.AddHours(-1.5);
                var windowEnd = requestedDateTime.AddHours(1.5);
                slotsQuery = slotsQuery.Where(ts =>
                    ts.StartTime >= windowStart && ts.StartTime <= windowEnd);
            }

            var restaurantIdsWithSlots = slotsQuery
                .Select(ts => ts.RestaurantId)
                .Distinct();

            restaurantQuery = restaurantQuery
                .Where(r => restaurantIdsWithSlots.Contains(r.RestaurantId));
        }

        // Sort by avg_rating DESC
        restaurantQuery = restaurantQuery.OrderByDescending(r => r.AvgRating);

        // Pagination
        var totalCount = await restaurantQuery.CountAsync();
        var restaurants = await restaurantQuery
            .Skip((pg - 1) * ps)
            .Take(ps)
            .ToListAsync();

        // Get available slots for the returned restaurants
        var restaurantIds = restaurants.Select(r => r.RestaurantId).ToList();
        var availableSlots = new Dictionary<Guid, List<AvailableSlotSummary>>();

        if (date.HasValue)
        {
            var slotDate = date.Value;
            var minCapacity = partySize ?? 1;

            var slotsQuery = db.TimeSlots
                .Where(ts => restaurantIds.Contains(ts.RestaurantId)
                    && ts.Date == slotDate
                    && ts.Status == "AVAILABLE"
                    && ts.Capacity >= minCapacity);

            if (time.HasValue)
            {
                var requestedDateTime = slotDate.ToDateTime(time.Value);
                var windowStart = requestedDateTime.AddHours(-1.5);
                var windowEnd = requestedDateTime.AddHours(1.5);
                slotsQuery = slotsQuery.Where(ts =>
                    ts.StartTime >= windowStart && ts.StartTime <= windowEnd);
            }

            var slots = await slotsQuery
                .OrderBy(ts => ts.StartTime)
                .Select(ts => new { ts.RestaurantId, ts.SlotId, ts.StartTime, ts.EndTime, ts.Capacity, TableGroupName = ts.TableGroup != null ? ts.TableGroup.Name : null })
                .ToListAsync();

            foreach (var slot in slots)
            {
                if (!availableSlots.ContainsKey(slot.RestaurantId))
                    availableSlots[slot.RestaurantId] = new List<AvailableSlotSummary>();

                availableSlots[slot.RestaurantId].Add(new AvailableSlotSummary
                {
                    SlotId = slot.SlotId,
                    StartTime = slot.StartTime,
                    EndTime = slot.EndTime,
                    Capacity = slot.Capacity,
                    TableGroupName = slot.TableGroupName
                });
            }
        }

        var results = restaurants.Select(r => new SearchResult
        {
            RestaurantId = r.RestaurantId,
            Name = r.Name,
            Cuisine = r.Cuisine,
            PriceLevel = r.PriceLevel,
            AvgRating = r.AvgRating,
            Address = r.Address,
            CoverImageUrl = r.CoverImageUrl,
            AvailableSlots = availableSlots.TryGetValue(r.RestaurantId, out var s)
                ? s.ToArray()
                : []
        }).ToArray();

        return Results.Ok(ApiResponse<object>.Ok(new
        {
            Results = results,
            Page = pg,
            PageSize = ps,
            TotalCount = totalCount
        }));
    })
    .WithName("SearchRestaurants")
    .WithOpenApi();

    // ==========================================================
    // GET /api/search/restaurants/{id} - Restaurant detail
    // ==========================================================
    app.MapGet("/api/search/restaurants/{id:guid}", async (
        Guid id,
        BooktableDbContext db,
        RedisService redis) =>
    {
        // Try cache first
        var cacheKey = $"restaurant:{id}";
        var cached = await redis.CheckIdempotencyKey(cacheKey);
        if (cached != null)
        {
            var cachedResult = JsonSerializer.Deserialize<RestaurantDetailResult>(cached,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            return Results.Ok(ApiResponse<RestaurantDetailResult>.Ok(cachedResult!));
        }

        var restaurant = await db.Restaurants
            .Where(r => r.RestaurantId == id && r.IsActive)
            .FirstOrDefaultAsync();

        if (restaurant is null)
            return Results.NotFound(ApiResponse<object>.Fail("Restaurant not found"));

        var tableGroups = await db.TableGroups
            .Where(tg => tg.RestaurantId == id)
            .OrderBy(tg => tg.DisplayOrder)
            .Select(tg => new { tg.TableGroupId, tg.Name, tg.Description })
            .ToListAsync();

        var reviewSummary = await db.Reviews
            .Where(r => r.RestaurantId == id)
            .GroupBy(r => r.RestaurantId)
            .Select(g => new { AvgRating = g.Average(r => r.Rating), Count = g.Count() })
            .FirstOrDefaultAsync();

        var result = new RestaurantDetailResult
        {
            RestaurantId = restaurant.RestaurantId,
            Name = restaurant.Name,
            Cuisine = restaurant.Cuisine,
            PriceLevel = restaurant.PriceLevel,
            AvgRating = restaurant.AvgRating,
            TotalReviews = restaurant.TotalReviews,
            Address = restaurant.Address,
            City = restaurant.City,
            State = restaurant.State,
            ZipCode = restaurant.ZipCode,
            Latitude = restaurant.Latitude,
            Longitude = restaurant.Longitude,
            Phone = restaurant.Phone,
            Website = restaurant.Website,
            Description = restaurant.Description,
            CoverImageUrl = restaurant.CoverImageUrl,
            OperatingHours = restaurant.OperatingHours,
            Amenities = restaurant.Amenities,
            TableGroups = tableGroups.Select(tg => new TableGroupSummary
            {
                TableGroupId = tg.TableGroupId,
                Name = tg.Name,
                Description = tg.Description
            }).ToArray()
        };

        // Cache for 60 seconds
        var json = JsonSerializer.Serialize(result);
        await redis.SetIdempotencyKey(cacheKey, json, 60);

        return Results.Ok(ApiResponse<RestaurantDetailResult>.Ok(result));
    })
    .WithName("GetRestaurantDetail")
    .WithOpenApi();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "SearchService terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// ==========================================================
// Restaurant detail response model (local to SearchService)
// ==========================================================
public class RestaurantDetailResult
{
    public Guid RestaurantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Cuisine { get; set; }
    public int? PriceLevel { get; set; }
    public decimal AvgRating { get; set; }
    public int TotalReviews { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? ZipCode { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string? Phone { get; set; }
    public string? Website { get; set; }
    public string? Description { get; set; }
    public string? CoverImageUrl { get; set; }
    public string OperatingHours { get; set; } = "{}";
    public string Amenities { get; set; } = "{}";
    public TableGroupSummary[] TableGroups { get; set; } = [];
}

public class TableGroupSummary
{
    public Guid TableGroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
}
