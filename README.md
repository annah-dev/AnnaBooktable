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
2. **DB Unique Constraint (L2)**  -  `UNIQUE(restaurant_id, table_id, start_time)`  -  THE SAFETY NET
3. **Idempotency Keys (L3)**  -  Prevents duplicate charges on retry

## Quick Start

```bash
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
```

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

```
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
```
