using AnnaBooktable.Shared.Infrastructure.Data;
using AnnaBooktable.Shared.Infrastructure.Middleware;
using AnnaBooktable.Shared.Infrastructure.Redis;
using Microsoft.AspNetCore.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

namespace AnnaBooktable.Shared.Infrastructure.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddBooktableDbContext(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<BooktableDbContext>(options =>
            options.UseNpgsql(connectionString));

        return services;
    }

    public static IServiceCollection AddRedisService(this IServiceCollection services, string connectionString)
    {
        var options = ConfigurationOptions.Parse(connectionString);
        options.AbortOnConnectFail = false;
        services.AddSingleton<IConnectionMultiplexer>(_ =>
            ConnectionMultiplexer.Connect(options));

        services.AddSingleton<RedisService>();

        return services;
    }

    public static IApplicationBuilder UseBooktableMiddleware(this IApplicationBuilder app)
    {
        app.UseMiddleware<RequestLoggingMiddleware>();
        app.UseMiddleware<ExceptionHandlingMiddleware>();
        return app;
    }
}
