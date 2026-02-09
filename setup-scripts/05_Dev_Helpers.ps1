<#
.SYNOPSIS
    Anna's Booktable  -  Daily Dev Helpers
    Quick commands for everyday development.

.EXAMPLE
    .\05_Dev_Helpers.ps1 start       # Start infrastructure + open tools
    .\05_Dev_Helpers.ps1 stop        # Stop infrastructure
    .\05_Dev_Helpers.ps1 status      # Show status of all services
    .\05_Dev_Helpers.ps1 logs        # Tail all container logs
    .\05_Dev_Helpers.ps1 db          # Open psql shell
    .\05_Dev_Helpers.ps1 redis       # Open redis-cli shell
    .\05_Dev_Helpers.ps1 seed-reset  # Re-run seed data (drops and recreates)
    .\05_Dev_Helpers.ps1 run-all     # Start all .NET services
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "status", "logs", "db", "redis", "seed-reset", "run-all")]
    [string]$Command = "status",

    [string]$ProjectRoot = "D:\Dev\AnnaBooktable"
)

$ErrorActionPreference = "SilentlyContinue"

Set-Location $ProjectRoot

switch ($Command) {

    "start" {
        Write-Host ">>> Starting Anna's Booktable infrastructure..." -ForegroundColor Cyan
        docker compose up -d
        Write-Host ""
        Write-Host "Infrastructure started! URLs:" -ForegroundColor Green
        Write-Host "  PostgreSQL:   localhost:5432" -ForegroundColor Gray
        Write-Host "  Redis:        localhost:6379" -ForegroundColor Gray
        Write-Host "  Elasticsearch:http://localhost:9200" -ForegroundColor Gray
        Write-Host "  RabbitMQ:     http://localhost:15672" -ForegroundColor Gray
        Write-Host "  Seq Logs:     http://localhost:8080" -ForegroundColor Gray
        Write-Host "  RedisInsight: http://localhost:5540" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To run .NET services:  .\05_Dev_Helpers.ps1 run-all" -ForegroundColor Yellow
    }

    "stop" {
        Write-Host ">>> Stopping infrastructure..." -ForegroundColor Yellow
        docker compose stop
        Write-Host "Done. Data preserved in Docker volumes." -ForegroundColor Green
    }

    "status" {
        Write-Host ">>> Service Status:" -ForegroundColor Cyan
        Write-Host ""
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        Write-Host ""

        # Quick data check
        $slots = docker exec booktable-postgres psql -U booktable_admin -d booktable -t -c "SELECT COUNT(*) FROM time_slots WHERE status='AVAILABLE';" 2>$null
        $res = docker exec booktable-postgres psql -U booktable_admin -d booktable -t -c "SELECT COUNT(*) FROM reservations;" 2>$null
        if ($slots) {
            Write-Host "  Available slots: $($slots.Trim())  |  Reservations: $($res.Trim())" -ForegroundColor Gray
        }
    }

    "logs" {
        Write-Host "  # Tailing container logs (Ctrl+C to stop)..." -ForegroundColor Cyan
        docker compose logs -f --tail 50
    }

    "db" {
        Write-Host ">>> Connecting to PostgreSQL..." -ForegroundColor Cyan
        docker exec -it booktable-postgres psql -U booktable_admin -d booktable
    }

    "redis" {
        Write-Host ">>> Connecting to Redis..." -ForegroundColor Cyan
        docker exec -it booktable-redis redis-cli
    }

    "seed-reset" {
        Write-Host ">>> Resetting seed data..." -ForegroundColor Yellow

        # Drop and recreate
        docker exec booktable-postgres psql -U booktable_admin -d booktable -c "
            TRUNCATE reviews, reservations, time_slots, tables, table_groups, restaurant_policies, users CASCADE;
        "
        Write-Host "  Tables truncated" -ForegroundColor Gray

        # Re-run seed
        $seedFile = Join-Path $ProjectRoot "db/init/02_seed_data.sql"
        if (Test-Path $seedFile) {
            Get-Content $seedFile -Raw | docker exec -i booktable-postgres psql -U booktable_admin -d booktable
            Write-Host "  [OK] Seed data reloaded" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Seed file not found: $seedFile" -ForegroundColor Red
        }
    }

    "run-all" {
        Write-Host ">>> Starting all .NET services..." -ForegroundColor Cyan
        Write-Host "  Each service will open in a new terminal window." -ForegroundColor Gray
        Write-Host ""

        $services = @(
            @{ Name = "Gateway";            Path = "src/Gateway";                    Port = 5000 },
            @{ Name = "Search Service";     Path = "src/Services/SearchService";     Port = 5001 },
            @{ Name = "Inventory Service";  Path = "src/Services/InventoryService";  Port = 5002 },
            @{ Name = "Reservation Service";Path = "src/Services/ReservationService";Port = 5003 },
            @{ Name = "Payment Service";    Path = "src/Services/PaymentService";    Port = 5004 }
        )

        foreach ($svc in $services) {
            $fullPath = Join-Path $ProjectRoot $svc.Path
            Start-Process wt -ArgumentList "new-tab", "--title", $svc.Name, "powershell", "-NoExit", "-Command", "cd '$fullPath'; dotnet run"
            Write-Host "  [OK] $($svc.Name) -> http://localhost:$($svc.Port)/swagger" -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "All services starting in Windows Terminal tabs." -ForegroundColor Green
        Write-Host "Gateway URL: http://localhost:5000" -ForegroundColor Yellow

        # Also offer to start React frontends
        Write-Host ""
        $startFrontend = Read-Host "Also start React frontends? (y/N)"
        if ($startFrontend -eq "y") {
            Start-Process wt -ArgumentList "new-tab", "--title", "Diner App", "powershell", "-NoExit", "-Command", "cd '$(Join-Path $ProjectRoot "src/diner-app")'; npm run dev"
            Start-Process wt -ArgumentList "new-tab", "--title", "Restaurant Portal", "powershell", "-NoExit", "-Command", "cd '$(Join-Path $ProjectRoot "src/restaurant-portal")'; npm run dev"
            Write-Host "  [OK] Diner App -> http://localhost:5173" -ForegroundColor Green
            Write-Host "  [OK] Restaurant Portal -> http://localhost:5174" -ForegroundColor Green
        }
    }
}
