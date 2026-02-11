using System.Text.Json;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace AnnaBooktable.Shared.Infrastructure.Redis;

public class RedisService
{
    private readonly IConnectionMultiplexer _redis;
    private readonly ILogger<RedisService> _logger;

    public RedisService(IConnectionMultiplexer redis, ILogger<RedisService> logger)
    {
        _redis = redis;
        _logger = logger;
    }

    private IDatabase Db => _redis.GetDatabase();

    // ============================================================
    // HOLD MANAGEMENT (Layer 1 - Redis SETNX)
    // Key format: hold:{slotId}  Value: {userId}:{holdToken}
    // ============================================================

    public async Task<(bool Success, string HoldToken)> TryAcquireHold(Guid slotId, Guid userId, int ttlSeconds = 300)
    {
        var holdToken = Guid.NewGuid().ToString("N");
        var key = $"hold:{slotId}";
        var value = $"{userId}:{holdToken}";

        try
        {
            // SETNX - atomic set-if-not-exists
            var acquired = await Db.StringSetAsync(key, value, TimeSpan.FromSeconds(ttlSeconds), When.NotExists);

            if (acquired)
            {
                _logger.LogInformation("Hold acquired for slot {SlotId} by user {UserId}, token {HoldToken}, TTL {Ttl}s",
                    slotId, userId, holdToken, ttlSeconds);
                return (true, holdToken);
            }

            // If hold already exists, check if it belongs to the same user (allows re-hold)
            var existing = await Db.StringGetAsync(key);
            if (!existing.IsNullOrEmpty)
            {
                var parts = existing.ToString().Split(':');
                if (parts.Length >= 1 && parts[0] == userId.ToString())
                {
                    // Same user - refresh TTL and return existing token
                    var existingToken = parts.Length >= 2 ? parts[1] : holdToken;
                    await Db.KeyExpireAsync(key, TimeSpan.FromSeconds(ttlSeconds));
                    _logger.LogInformation("Hold refreshed for slot {SlotId} by same user {UserId}", slotId, userId);
                    return (true, existingToken);
                }
            }

            _logger.LogInformation("Hold denied for slot {SlotId} - already held by another user", slotId);
            return (false, string.Empty);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error acquiring hold for slot {SlotId}", slotId);
            return (false, string.Empty);
        }
    }

    public async Task<bool> ValidateHold(Guid slotId, string holdToken)
    {
        try
        {
            var key = $"hold:{slotId}";
            var value = await Db.StringGetAsync(key);

            if (value.IsNullOrEmpty)
                return false;

            // Value format is {userId}:{holdToken}
            var storedToken = value.ToString().Split(':').LastOrDefault();
            return storedToken == holdToken;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error validating hold for slot {SlotId}", slotId);
            return false;
        }
    }

    public async Task ReleaseHold(Guid slotId)
    {
        try
        {
            var key = $"hold:{slotId}";
            await Db.KeyDeleteAsync(key);
            _logger.LogInformation("Hold released for slot {SlotId}", slotId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error releasing hold for slot {SlotId}", slotId);
        }
    }

    // ============================================================
    // AVAILABILITY CACHE
    // Key format: avail:{restaurantId}:{date}
    // ============================================================

    public async Task<string?> GetCachedAvailability(Guid restaurantId, DateOnly date)
    {
        try
        {
            var key = $"avail:{restaurantId}:{date:yyyy-MM-dd}";
            var value = await Db.StringGetAsync(key);
            return value.IsNullOrEmpty ? null : value.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error getting cached availability for restaurant {RestaurantId}", restaurantId);
            return null;
        }
    }

    public async Task SetCachedAvailability(Guid restaurantId, DateOnly date, string slotsJson, int ttlSeconds = 60)
    {
        try
        {
            var key = $"avail:{restaurantId}:{date:yyyy-MM-dd}";
            await Db.StringSetAsync(key, slotsJson, TimeSpan.FromSeconds(ttlSeconds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error setting cached availability for restaurant {RestaurantId}", restaurantId);
        }
    }

    public async Task InvalidateCachedAvailability(Guid restaurantId, DateOnly date)
    {
        try
        {
            var key = $"avail:{restaurantId}:{date:yyyy-MM-dd}";
            await Db.KeyDeleteAsync(key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error invalidating cached availability for restaurant {RestaurantId}", restaurantId);
        }
    }

    // ============================================================
    // IDEMPOTENCY KEYS (Layer 3)
    // Key format: idem:{key}
    // ============================================================

    public async Task<string?> CheckIdempotencyKey(string key)
    {
        try
        {
            var redisKey = $"idem:{key}";
            var value = await Db.StringGetAsync(redisKey);
            return value.IsNullOrEmpty ? null : value.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error checking idempotency key {Key}", key);
            return null;
        }
    }

    public async Task SetIdempotencyKey(string key, string responseJson, int ttlSeconds = 86400)
    {
        try
        {
            var redisKey = $"idem:{key}";
            await Db.StringSetAsync(redisKey, responseJson, TimeSpan.FromSeconds(ttlSeconds));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error setting idempotency key {Key}", key);
        }
    }

    // ============================================================
    // ADMIN SETTINGS (booktable:settings hash)
    // ============================================================

    public async Task<Dictionary<string, string>> GetSettings()
    {
        try
        {
            var entries = await Db.HashGetAllAsync("booktable:settings");
            return entries.ToDictionary(e => e.Name.ToString(), e => e.Value.ToString());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error reading settings");
            return new Dictionary<string, string>();
        }
    }

    public async Task<string?> GetSetting(string key)
    {
        try
        {
            var value = await Db.HashGetAsync("booktable:settings", key);
            return value.IsNullOrEmpty ? null : value.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Redis error reading setting {Key}", key);
            return null;
        }
    }
}
