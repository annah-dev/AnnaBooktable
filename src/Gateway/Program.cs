using AnnaBooktable.Shared.Infrastructure.Middleware;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((context, config) =>
        config.ReadFrom.Configuration(context.Configuration));

    // YARP Reverse Proxy
    builder.Services.AddReverseProxy()
        .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

    // CORS for React frontend
    var allowedOrigins = builder.Configuration.GetValue<string>("ALLOWED_ORIGINS")?.Split(',')
        ?? ["http://localhost:5173", "https://localhost:5173"];
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("Frontend", policy =>
        {
            policy.WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials();
        });
    });

    // HTTP clients for health checks
    builder.Services.AddHttpClient();

    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();

    var app = builder.Build();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    // Request logging
    app.UseMiddleware<RequestLoggingMiddleware>();

    app.UseCors("Frontend");

    // ==========================================================
    // GET /health - Health check endpoint
    // ==========================================================
    app.MapGet("/health", async (IHttpClientFactory httpClientFactory) =>
    {
        var results = new Dictionary<string, string>();
        var client = httpClientFactory.CreateClient();
        client.Timeout = TimeSpan.FromSeconds(5);

        var config = app.Configuration;
        var services = new Dictionary<string, string>
        {
            ["search"] = config["ServiceUrls:Search"] ?? "http://localhost:5001",
            ["inventory"] = config["ServiceUrls:Inventory"] ?? "http://localhost:5002",
            ["reservations"] = config["ServiceUrls:Reservations"] ?? "http://localhost:5003",
            ["payments"] = config["ServiceUrls:Payments"] ?? "http://localhost:5004"
        };

        // Check all services in parallel
        var tasks = services.Select(async svc =>
        {
            try
            {
                var response = await client.GetAsync($"{svc.Value}/swagger/v1/swagger.json");
                return (svc.Key, Status: "up");
            }
            catch
            {
                return (svc.Key, Status: "down");
            }
        });

        foreach (var result in await Task.WhenAll(tasks))
            results[result.Key] = result.Status;

        var overallStatus = results.Values.All(v => v == "up") ? "healthy"
            : results.Values.Any(v => v == "up") ? "degraded"
            : "unhealthy";

        return Results.Ok(new
        {
            Status = overallStatus,
            Services = results,
            Timestamp = DateTime.UtcNow
        });
    })
    .WithName("HealthCheck")
    .WithOpenApi();

    app.MapReverseProxy();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Gateway terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
