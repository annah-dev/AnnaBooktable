<#
.SYNOPSIS
    Anna's Booktable  -  Project Scaffolding
    Creates the complete .NET solution, microservices, shared libraries,
    React frontends, and docker-compose infrastructure.
#>

param(
    [string]$ProjectRoot = "D:\Dev\AnnaBooktable"
)

$ErrorActionPreference = "Stop"

function Write-Step   { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK     { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip   { param($msg) Write-Host "  [SKIP]  $msg" -ForegroundColor DarkGray }

# ============================================================
# Create Project Root
# ============================================================
Write-Step "Creating project directory: $ProjectRoot"

if (-not (Test-Path $ProjectRoot)) {
    New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
    Write-OK "Created $ProjectRoot"
} else {
    Write-Skip "Directory already exists"
}

Set-Location $ProjectRoot

# ============================================================
# Initialize Git
# ============================================================
Write-Step "Initializing Git repository"

if (-not (Test-Path ".git")) {
    git init
    Write-OK "Git initialized"
} else {
    Write-Skip "Git already initialized"
}

# ============================================================
# Create .NET Solution
# ============================================================
Write-Step "Creating .NET Solution"

if (-not (Test-Path "AnnaBooktable.sln")) {
    dotnet new sln -n AnnaBooktable
    Write-OK "Solution created"
} else {
    Write-Skip "Solution already exists"
}

# ============================================================
# Create Projects
# ============================================================
$projects = @(
    # Gateway
    @{ Name = "AnnaBooktable.Gateway";              Path = "src/Gateway";                    Template = "webapi" },

    # Core Services
    @{ Name = "AnnaBooktable.SearchService";        Path = "src/Services/SearchService";     Template = "webapi" },
    @{ Name = "AnnaBooktable.InventoryService";     Path = "src/Services/InventoryService";  Template = "webapi" },
    @{ Name = "AnnaBooktable.ReservationService";   Path = "src/Services/ReservationService";Template = "webapi" },
    @{ Name = "AnnaBooktable.PaymentService";       Path = "src/Services/PaymentService";    Template = "webapi" },

    # Shared Libraries
    @{ Name = "AnnaBooktable.Shared.Models";        Path = "src/Shared/Models";              Template = "classlib" },
    @{ Name = "AnnaBooktable.Shared.Events";        Path = "src/Shared/Events";              Template = "classlib" },
    @{ Name = "AnnaBooktable.Shared.Infrastructure";Path = "src/Shared/Infrastructure";      Template = "classlib" },

    # Tests
    @{ Name = "AnnaBooktable.Tests.Unit";           Path = "tests/Unit";                     Template = "xunit" },
    @{ Name = "AnnaBooktable.Tests.Integration";    Path = "tests/Integration";              Template = "xunit" }
)

Write-Step "Creating .NET projects"

foreach ($proj in $projects) {
    $csprojPath = Join-Path $ProjectRoot "$($proj.Path)/$($proj.Name).csproj"
    if (-not (Test-Path $csprojPath)) {
        dotnet new $proj.Template -n $proj.Name -o $proj.Path --no-restore
        dotnet sln add $proj.Path
        Write-OK $proj.Name
    } else {
        Write-Skip $proj.Name
    }
}

# ============================================================
# Add NuGet Package References
# ============================================================
Write-Step "Adding NuGet packages"

$packageSets = @{
    "src/Shared/Models" = @(
        "System.ComponentModel.Annotations"
    )
    "src/Shared/Infrastructure" = @(
        "Npgsql.EntityFrameworkCore.PostgreSQL",
        "StackExchange.Redis",
        "Microsoft.EntityFrameworkCore.Design",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq"
    )
    "src/Shared/Events" = @(
        "MassTransit",
        "MassTransit.RabbitMQ"
    )
    "src/Gateway" = @(
        "Yarp.ReverseProxy",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq"
    )
    "src/Services/SearchService" = @(
        "NEST",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq",
        "MassTransit",
        "MassTransit.RabbitMQ"
    )
    "src/Services/InventoryService" = @(
        "StackExchange.Redis",
        "Npgsql.EntityFrameworkCore.PostgreSQL",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq",
        "MassTransit",
        "MassTransit.RabbitMQ"
    )
    "src/Services/ReservationService" = @(
        "Npgsql.EntityFrameworkCore.PostgreSQL",
        "StackExchange.Redis",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq",
        "MassTransit",
        "MassTransit.RabbitMQ"
    )
    "src/Services/PaymentService" = @(
        "Stripe.net",
        "Serilog.AspNetCore",
        "Serilog.Sinks.Seq",
        "MassTransit",
        "MassTransit.RabbitMQ"
    )
    "tests/Unit" = @(
        "Moq",
        "FluentAssertions"
    )
    "tests/Integration" = @(
        "Microsoft.AspNetCore.Mvc.Testing",
        "Testcontainers.PostgreSql",
        "Testcontainers.Redis",
        "FluentAssertions"
    )
}

foreach ($projPath in $packageSets.Keys) {
    Write-Host "    Packages for $projPath..." -ForegroundColor Gray
    foreach ($pkg in $packageSets[$projPath]) {
        dotnet add $projPath package $pkg --no-restore 2>$null
    }
}

# Add project references
Write-Host "    Adding project references..." -ForegroundColor Gray
$serviceProjects = @(
    "src/Services/SearchService",
    "src/Services/InventoryService",
    "src/Services/ReservationService",
    "src/Services/PaymentService",
    "src/Gateway"
)

foreach ($svcPath in $serviceProjects) {
    dotnet add $svcPath reference "src/Shared/Models" 2>$null
    dotnet add $svcPath reference "src/Shared/Events" 2>$null
    dotnet add $svcPath reference "src/Shared/Infrastructure" 2>$null
}

dotnet add "tests/Unit" reference "src/Shared/Models" 2>$null
dotnet add "tests/Integration" reference "src/Shared/Models" 2>$null

Write-OK "All packages and references added"

# ============================================================
# NuGet Restore
# ============================================================
Write-Step "Restoring NuGet packages"
dotnet restore
Write-OK "Packages restored"

# ============================================================
# Create Database Init Scripts
# ============================================================
Write-Step "Creating database init scripts"

$dbDir = Join-Path $ProjectRoot "db/init"
New-Item -ItemType Directory -Path $dbDir -Force | Out-Null

$schemaFile = Join-Path $dbDir "01_schema.sql"
if (-not (Test-Path $schemaFile)) {
    # Schema will be created by the dedicated SQL file
    Write-OK "Database directory created at db/init/"
} else {
    Write-Skip "Schema file already exists"
}

# ============================================================
# Create React Frontends
# ============================================================
Write-Step "Creating React frontends"

$frontendDir = Join-Path $ProjectRoot "src"

# Diner App
$dinerPath = Join-Path $frontendDir "diner-app"
if (-not (Test-Path "$dinerPath/package.json")) {
    Set-Location $frontendDir
    npm create vite@latest diner-app -- --template react-ts 2>$null
    Set-Location $dinerPath
    npm install 2>$null
    npm install react-router-dom axios @tanstack/react-query tailwindcss @headlessui/react @heroicons/react date-fns 2>$null
    Write-OK "Diner App created (React + TypeScript + Tailwind)"
} else {
    Write-Skip "Diner App already exists"
}

# Restaurant Portal
$portalPath = Join-Path $frontendDir "restaurant-portal"
if (-not (Test-Path "$portalPath/package.json")) {
    Set-Location $frontendDir
    npm create vite@latest restaurant-portal -- --template react-ts 2>$null
    Set-Location $portalPath
    npm install 2>$null
    npm install react-router-dom axios @tanstack/react-query tailwindcss recharts @headlessui/react @heroicons/react date-fns 2>$null
    Write-OK "Restaurant Portal created (React + TypeScript + Tailwind + Recharts)"
} else {
    Write-Skip "Restaurant Portal already exists"
}

Set-Location $ProjectRoot

# ============================================================
# Create docker-compose.yml
# ============================================================
Write-Step "Creating docker-compose.yml"

$composeFile = Join-Path $ProjectRoot "docker-compose.yml"
if (-not (Test-Path $composeFile)) {
    # Will be created by the Docker setup script
    Write-OK "Docker compose will be created in Step 9"
} else {
    Write-Skip "docker-compose.yml already exists"
}

# ============================================================
# Create .gitignore
# ============================================================
Write-Step "Creating .gitignore"

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    dotnet new gitignore

    # Append additional ignores
    @"

# ===== Anna's Booktable additions =====

# Node modules (React frontends)
node_modules/
dist/

# Docker volumes
postgres_data/
redis_data/
es_data/

# Local environment files
.env.local
.env.development.local
appsettings.Development.local.json

# IDE
.idea/
*.suo
*.user

# OS
.DS_Store
Thumbs.db

# Setup progress file
.booktable_setup_progress
"@ | Out-File -Append -FilePath $gitignorePath

    Write-OK ".gitignore created"
} else {
    Write-Skip ".gitignore already exists"
}

# ============================================================
# Create README.md
# ============================================================
Write-Step "Creating README.md"

$readmePath = Join-Path $ProjectRoot "README.md"
if (-not (Test-Path $readmePath)) {
    @"
# Anna's Booktable --

A production-grade restaurant reservation platform built with .NET 8 microservices, React, and defense-in-depth concurrency control.

## Architecture

- **API Gateway**  -  YARP reverse proxy with auth and rate limiting
- **Search Service**  -  Elasticsearch-powered restaurant search
- **Inventory Service**  -  Redis holds + real-time availability
- **Reservation Service**  -  Booking orchestration with DB unique constraints
- **Payment Service**  -  Stripe integration with idempotency
- **Diner App**  -  React/TypeScript frontend for diners
- **Restaurant Portal**  -  React/TypeScript dashboard for restaurant owners

## Defense-in-Depth (3 Layers)

1. **Redis Holds (L1)**  -  5-minute slot protection during checkout
2. **DB Unique Constraint (L2)**  -  ``UNIQUE(restaurant_id, table_id, start_time)``  -  THE SAFETY NET
3. **Idempotency Keys (L3)**  -  Prevents duplicate charges on retry

## Quick Start

``````bash
# Start infrastructure
docker compose up -d

# Run all services (from Visual Studio or terminal)
dotnet run --project src/Gateway
dotnet run --project src/Services/SearchService
dotnet run --project src/Services/InventoryService
dotnet run --project src/Services/ReservationService
dotnet run --project src/Services/PaymentService

# Run diner frontend
cd src/diner-app && npm run dev

# Run restaurant portal
cd src/restaurant-portal && npm run dev
``````

## Tech Stack

| Layer          | Technology                    |
|----------------|-------------------------------|
| Backend        | .NET 8 / C# / ASP.NET Core   |
| Frontend       | React 18 / TypeScript / Vite  |
| Database       | PostgreSQL 16                 |
| Cache / Holds  | Redis 7                       |
| Search         | Elasticsearch 8               |
| Message Bus    | RabbitMQ (Azure Service Bus in prod) |
| Payments       | Stripe                        |
| Gateway        | YARP Reverse Proxy            |
| Logging        | Serilog + Seq                 |

## Project Structure

``````
AnnaBooktable/
|-- src/
|   |-- Gateway/                   # YARP reverse proxy
|   |-- Services/
|   |   |-- SearchService/         # Elasticsearch queries
|   |   |-- InventoryService/      # Availability + Redis holds
|   |   |-- ReservationService/    # Booking orchestration
|   |   +-- PaymentService/        # Stripe integration
|   |-- Shared/
|   |   |-- Models/                # DTOs, entities
|   |   |-- Events/                # Message bus events
|   |   +-- Infrastructure/        # DB context, Redis helpers
|   |-- diner-app/                 # React diner frontend
|   +-- restaurant-portal/         # React restaurant dashboard
|-- tests/
|-- db/init/                       # SQL schema + seed data
|-- docker-compose.yml             # Local infrastructure
+-- setup-scripts/                 # Dev environment automation
``````
"@ | Out-File -FilePath $readmePath -Encoding utf8

    Write-OK "README.md created"
} else {
    Write-Skip "README.md already exists"
}

# ============================================================
# Create solution-level Directory.Build.props
# ============================================================
Write-Step "Creating Directory.Build.props"

$buildPropsPath = Join-Path $ProjectRoot "Directory.Build.props"
if (-not (Test-Path $buildPropsPath)) {
    @"
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
"@ | Out-File -FilePath $buildPropsPath -Encoding utf8

    Write-OK "Directory.Build.props created"
} else {
    Write-Skip "Directory.Build.props already exists"
}

# ============================================================
# Create launch profiles for each service
# ============================================================
Write-Step "Creating service launch profiles"

$portMap = @{
    "src/Gateway"                    = 5000
    "src/Services/SearchService"     = 5001
    "src/Services/InventoryService"  = 5002
    "src/Services/ReservationService"= 5003
    "src/Services/PaymentService"    = 5004
}

foreach ($svcPath in $portMap.Keys) {
    $port = $portMap[$svcPath]
    $propsDir = Join-Path $ProjectRoot "$svcPath/Properties"
    $launchFile = Join-Path $propsDir "launchSettings.json"

    New-Item -ItemType Directory -Path $propsDir -Force | Out-Null

    $svcName = Split-Path $svcPath -Leaf
    $launchContent = @"
{
  "profiles": {
    "$svcName": {
      "commandName": "Project",
      "launchBrowser": true,
      "launchUrl": "swagger",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      },
      "applicationUrl": "https://localhost:$($port + 1000);http://localhost:$port"
    }
  }
}
"@
    $launchContent | Out-File -FilePath $launchFile -Encoding utf8
}

Write-OK "Launch profiles created (ports 5000-5004)"

# ============================================================
# Create appsettings.Development.json for each service
# ============================================================
Write-Step "Creating development appsettings"

$baseAppSettings = @{
    "ConnectionStrings" = @{
        "PostgreSQL"    = "Host=localhost;Port=5432;Database=booktable;Username=booktable_admin;Password=LocalDev123!"
        "Redis"         = "localhost:6379"
        "Elasticsearch" = "http://localhost:9200"
        "RabbitMQ"      = "amqp://guest:guest@localhost:5672"
    }
    "Serilog" = @{
        "MinimumLevel" = @{
            "Default" = "Information"
            "Override" = @{
                "Microsoft.AspNetCore" = "Warning"
                "Microsoft.EntityFrameworkCore" = "Warning"
            }
        }
        "WriteTo" = @(
            @{ "Name" = "Console" },
            @{ "Name" = "Seq"; "Args" = @{ "serverUrl" = "http://localhost:5341" } }
        )
    }
}

$serviceAppsettings = @{
    "src/Gateway" = @{
        "ReverseProxy" = @{
            "Routes" = @{
                "search"      = @{ "ClusterId" = "search";      "Match" = @{ "Path" = "/api/search/{**catch-all}" } }
                "inventory"   = @{ "ClusterId" = "inventory";   "Match" = @{ "Path" = "/api/inventory/{**catch-all}" } }
                "reservations"= @{ "ClusterId" = "reservations";"Match" = @{ "Path" = "/api/reservations/{**catch-all}" } }
                "payments"    = @{ "ClusterId" = "payments";    "Match" = @{ "Path" = "/api/payments/{**catch-all}" } }
            }
            "Clusters" = @{
                "search"      = @{ "Destinations" = @{ "default" = @{ "Address" = "http://localhost:5001" } } }
                "inventory"   = @{ "Destinations" = @{ "default" = @{ "Address" = "http://localhost:5002" } } }
                "reservations"= @{ "Destinations" = @{ "default" = @{ "Address" = "http://localhost:5003" } } }
                "payments"    = @{ "Destinations" = @{ "default" = @{ "Address" = "http://localhost:5004" } } }
            }
        }
    }
    "src/Services/PaymentService" = @{
        "Stripe" = @{
            "SecretKey"      = "sk_test_YOUR_KEY_HERE"
            "WebhookSecret"  = "whsec_YOUR_SECRET_HERE"
        }
    }
}

foreach ($svcPath in $portMap.Keys) {
    $settingsFile = Join-Path $ProjectRoot "$svcPath/appsettings.Development.json"

    $settings = $baseAppSettings.Clone()
    if ($serviceAppsettings.ContainsKey($svcPath)) {
        foreach ($key in $serviceAppsettings[$svcPath].Keys) {
            $settings[$key] = $serviceAppsettings[$svcPath][$key]
        }
    }

    $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $settingsFile -Encoding utf8
}

Write-OK "Development appsettings created for all services"

# ============================================================
# Copy setup scripts into project
# ============================================================
Write-Step "Copying setup scripts to project"

$setupScriptsDir = Join-Path $ProjectRoot "setup-scripts"
New-Item -ItemType Directory -Path $setupScriptsDir -Force | Out-Null

$scriptDir = $PSScriptRoot
if ($scriptDir) {
    $scriptFiles = Get-ChildItem -Path $scriptDir -Filter "*.ps1"
    foreach ($file in $scriptFiles) {
        Copy-Item $file.FullName -Destination $setupScriptsDir -Force
    }
    Write-OK "Setup scripts copied to setup-scripts/"
}

# Also copy SQL files if present
$sqlSource = Join-Path $scriptDir "01_schema.sql"
if (Test-Path $sqlSource) {
    Copy-Item $sqlSource -Destination (Join-Path $ProjectRoot "db/init/01_schema.sql") -Force
    Write-OK "Schema SQL copied to db/init/"
}

$seedSource = Join-Path $scriptDir "02_seed_data.sql"
if (Test-Path $seedSource) {
    Copy-Item $seedSource -Destination (Join-Path $ProjectRoot "db/init/02_seed_data.sql") -Force
    Write-OK "Seed data SQL copied to db/init/"
}

Write-Host ""
Write-OK "Project scaffolding complete!"
Write-Host "    Solution: $ProjectRoot\AnnaBooktable.sln" -ForegroundColor Gray
