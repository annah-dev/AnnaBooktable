# AnnaBooktable — Complete Deployment Guide

> Last updated: 2026-02-11. This guide was written after hours of debugging deployment
> issues. Follow it exactly — every warning is from hard-won experience.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Azure Resources](#2-azure-resources)
3. [Local Development Setup](#3-local-development-setup)
4. [Deploying Backend Services (.NET 8)](#4-deploying-backend-services-net-8)
5. [Deploying the Frontend (React/Node)](#5-deploying-the-frontend-reactnode)
6. [Deploying the Monitor Tool](#6-deploying-the-monitor-tool)
7. [Database Setup (Azure PostgreSQL)](#7-database-setup-azure-postgresql)
8. [Azure App Settings Reference](#8-azure-app-settings-reference)
9. [Pitfalls & Lessons Learned](#9-pitfalls--lessons-learned)
10. [Troubleshooting](#10-troubleshooting)
11. [Cleanup](#11-cleanup)

---

## 1. Architecture Overview

```
Browser
  │
  ▼
[Frontend SPA]  ── anna-booktable-frontend (Node 20, Express)
  │                  serves static React build from /dist
  │
  ▼  (HTTPS)
[Gateway]       ── anna-booktable-gateway (DOTNETCORE|8.0, YARP reverse proxy)
  │                  routes /api/search/*, /api/inventory/*, etc.
  │
  ├──► [Search Service]      ── anna-booktable-search      :5001
  ├──► [Inventory Service]   ── anna-booktable-inventory    :5002
  ├──► [Reservation Service] ── anna-booktable-reservation  :5003
  └──► [Payment Service]     ── anna-booktable-payment      :5004
          │
          ▼
    [PostgreSQL]  ── anna-booktable-pg (Central US)
    [Redis]       ── anna-booktable-redis (West US 2)
    [Service Bus] ── anna-booktable-bus (MassTransit, unused in current prod)

[Monitor]       ── anna-booktable-monitor (Node 20, WebSocket dashboard)
```

**Ports (local dev only):**
| Service | Port |
|---------|------|
| Gateway | 5000 |
| Search | 5001 |
| Inventory | 5002 |
| Reservation | 5003 |
| Payment | 5004 |
| Frontend (Vite dev) | 5173 |
| Monitor | 3099 |

---

## 2. Azure Resources

**Resource group:** `anna-booktable-rg` (West US 2)

| Component | Azure Service | Name | Region | SKU |
|-----------|--------------|------|--------|-----|
| Database | PostgreSQL Flexible Server | anna-booktable-pg | Central US | Standard_B1ms |
| Cache | Azure Cache for Redis | anna-booktable-redis | West US 2 | Basic C0 |
| Messaging | Service Bus | anna-booktable-bus | West US 2 | Basic |
| Compute | App Service Plan (Linux) | anna-booktable-plan | West US 2 | B1 |
| Gateway | App Service (DOTNETCORE\|8.0) | anna-booktable-gateway | West US 2 | shared plan |
| Search API | App Service (DOTNETCORE\|8.0) | anna-booktable-search | West US 2 | shared plan |
| Inventory API | App Service (DOTNETCORE\|8.0) | anna-booktable-inventory | West US 2 | shared plan |
| Reservation API | App Service (DOTNETCORE\|8.0) | anna-booktable-reservation | West US 2 | shared plan |
| Payment API | App Service (DOTNETCORE\|8.0) | anna-booktable-payment | West US 2 | shared plan |
| Frontend | App Service (NODE\|20-lts) | anna-booktable-frontend | West US 2 | shared plan |
| Monitor | App Service (NODE\|20-lts) | anna-booktable-monitor | West US 2 | shared plan |
| Log Analytics | Log Analytics Workspace | workspace-annabooktablerge4nK | West US 2 | — |
| Container Env | Container App Environment | anna-booktable-env | West US 2 | — |

**Live URLs:**
| Service | URL |
|---------|-----|
| Frontend | https://anna-booktable-frontend.azurewebsites.net |
| Gateway API | https://anna-booktable-gateway.azurewebsites.net |
| Health Check | https://anna-booktable-gateway.azurewebsites.net/health |
| Monitor | https://anna-booktable-monitor.azurewebsites.net |

---

## 3. Local Development Setup

### Prerequisites
- Docker Desktop (for PostgreSQL, Redis, Elasticsearch, RabbitMQ, Seq)
- .NET SDK (project targets `net8.0` — the SDK can be 8.x or 10.x)
- Node.js 20+
- Azure CLI (`az`) with Python

### Start Infrastructure

```bash
cd D:\Dev\AnnaBooktable
docker compose up -d
```

This starts:
| Container | Port | Purpose |
|-----------|------|---------|
| booktable-postgres | 5432 | PostgreSQL 16 (user: `booktable_admin`, pass: `LocalDev123!`, db: `booktable`) |
| booktable-redis | 6379 | Redis 7 (no auth) |
| booktable-elasticsearch | 9200 | Elasticsearch 8.12 (security disabled) |
| booktable-rabbitmq | 5672, 15672 | RabbitMQ 3 (guest/guest, management UI at 15672) |
| booktable-seq | 5341, 8080 | Seq structured logging (ingest 5341, UI at 8080) |
| booktable-redis-insight | 5540 | Redis GUI (optional) |

**Important:** DB init scripts (`db/init/01_schema.sql`, `02_seed_data.sql`) only run on
first container creation. If the volume already exists, run them manually:
```bash
docker exec -i booktable-postgres psql -U booktable_admin -d booktable < db/init/01_schema.sql
docker exec -i booktable-postgres psql -U booktable_admin -d booktable < db/init/02_seed_data.sql
```

### Start Backend Services

Each service MUST have `ASPNETCORE_ENVIRONMENT=Development` to load `appsettings.Development.json`.

```bash
# Terminal 1 — Gateway
set ASPNETCORE_ENVIRONMENT=Development && dotnet run --project src/Gateway

# Terminal 2 — Search
set ASPNETCORE_ENVIRONMENT=Development && dotnet run --project src/Services/SearchService

# Terminal 3 — Inventory
set ASPNETCORE_ENVIRONMENT=Development && dotnet run --project src/Services/InventoryService

# Terminal 4 — Reservation
set ASPNETCORE_ENVIRONMENT=Development && dotnet run --project src/Services/ReservationService

# Terminal 5 — Payment
set ASPNETCORE_ENVIRONMENT=Development && dotnet run --project src/Services/PaymentService
```

### Start Frontend

```bash
cd src/diner-app
npm install
npm run dev
# Opens at http://localhost:5173 → proxies API to http://localhost:5000
```

---

## 4. Deploying Backend Services (.NET 8)

### Step 1: Publish

```bash
# From repo root. Replace {ServiceName} and {service-name} as needed.
dotnet publish src/Services/SearchService/AnnaBooktable.SearchService.csproj -c Release -o publish/search
dotnet publish src/Services/InventoryService/AnnaBooktable.InventoryService.csproj -c Release -o publish/inventory
dotnet publish src/Services/ReservationService/AnnaBooktable.ReservationService.csproj -c Release -o publish/reservation
dotnet publish src/Services/PaymentService/AnnaBooktable.PaymentService.csproj -c Release -o publish/payment
dotnet publish src/Gateway/AnnaBooktable.Gateway.csproj -c Release -o publish/gateway
```

### Step 2: Create Deployment Zip

> **CRITICAL: NEVER use PowerShell `Compress-Archive` for zips deployed to Linux.**
> It creates Windows-style backslash paths (`assets\file.js`) that are invalid filenames
> on Linux, causing silent file corruption and 503 crash loops that are extremely hard to debug.

Use Node.js `archiver` or any tool that produces forward-slash paths:

```javascript
// quick-zip.mjs — generic zip helper
import archiver from 'archiver';
import fs from 'fs';
const [, , sourceDir, outputPath] = process.argv;
const output = fs.createWriteStream(outputPath);
const archive = archiver('zip', { zlib: { level: 6 } });
archive.pipe(output);
archive.directory(sourceDir + '/', false);  // false = no prefix directory
output.on('close', () => console.log(`Zip: ${(archive.pointer() / 1024).toFixed(0)} KB → ${outputPath}`));
archive.finalize();
```

```bash
# Example: zip the search service
node quick-zip.mjs publish/search deploy-search.zip
```

**Alternative** — if you must use the command line and have `7z` or `tar`:
```bash
# 7-Zip (produces correct paths)
cd publish/search && 7z a -tzip ../../deploy-search.zip . && cd ../..

# Or tar-based zip
cd publish/search && tar -acf ../../deploy-search.zip . && cd ../..
```

### Step 3: Deploy to Azure

```bash
az webapp deploy \
  --resource-group anna-booktable-rg \
  --name anna-booktable-search \
  --src-path deploy-search.zip \
  --type zip \
  --clean true
```

The `--clean true` flag removes old files before extracting the new zip.

Repeat for each service:
```bash
az webapp deploy -g anna-booktable-rg -n anna-booktable-gateway   --src-path deploy-gateway.zip   --type zip --clean true
az webapp deploy -g anna-booktable-rg -n anna-booktable-search    --src-path deploy-search.zip    --type zip --clean true
az webapp deploy -g anna-booktable-rg -n anna-booktable-inventory --src-path deploy-inventory.zip --type zip --clean true
az webapp deploy -g anna-booktable-rg -n anna-booktable-reservation --src-path deploy-reservation.zip --type zip --clean true
az webapp deploy -g anna-booktable-rg -n anna-booktable-payment   --src-path deploy-payment.zip   --type zip --clean true
```

### Step 4: Verify

```bash
# Check health endpoint (goes through Gateway → all services)
curl https://anna-booktable-gateway.azurewebsites.net/health

# Check individual service logs
az webapp log tail -g anna-booktable-rg -n anna-booktable-search
```

### Key App Settings for Backend Services

All .NET services need:
- `ASPNETCORE_ENVIRONMENT=Production`
- `SCM_DO_BUILD_DURING_DEPLOYMENT=false`
- `WEBSITE_RUN_FROM_PACKAGE=1` (runs from zip, prevents file mutation)

See [Section 8](#8-azure-app-settings-reference) for the full settings per service.

---

## 5. Deploying the Frontend (React/Node)

The frontend is a React 19 SPA served by a tiny Express server (`server.cjs`).

### Step 1: Build

```bash
cd src/diner-app
npm run build
```

The API URL is baked in at build time from `.env.production`:
```
VITE_API_URL=https://anna-booktable-gateway.azurewebsites.net
```

### Step 2: Create Deployment Zip

```bash
cd src/diner-app
node bundle-deploy.mjs
# Output: D:\Dev\AnnaBooktable\frontend-deploy.zip (~120 KB + node_modules)
```

**What `bundle-deploy.mjs` does:**
1. Installs `express` into a temp `_deploy_modules/` directory
2. Bundles into a zip with forward-slash paths:
   - `dist/` — the Vite build output (index.html, JS, CSS)
   - `node_modules/` — just express and its dependencies
   - `server.cjs` — the Express SPA server
   - `package.json` — minimal, with `"start": "node server.cjs"`

**Why include node_modules instead of using `SCM_DO_BUILD_DURING_DEPLOYMENT`?**
Azure Oryx build creates a symlink `node_modules → /node_modules` but `/node_modules` ends
up empty, causing `require('express')` to fail. Bundling node_modules directly is reliable.

### Step 3: Deploy

```bash
az webapp deploy \
  --resource-group anna-booktable-rg \
  --name anna-booktable-frontend \
  --src-path D:/Dev/AnnaBooktable/frontend-deploy.zip \
  --type zip \
  --clean true
```

### Step 4: Restart (if the site doesn't come up automatically)

```bash
az webapp restart -g anna-booktable-rg -n anna-booktable-frontend
```

### Step 5: Verify

```bash
curl -sI https://anna-booktable-frontend.azurewebsites.net/
# Should return HTTP 200 with X-Powered-By: Express
```

### Frontend App Settings

| Setting | Value |
|---------|-------|
| Startup command | `node server.cjs` |
| WEBSITES_PORT | 8080 |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITES_ENABLE_APP_SERVICE_STORAGE | true |
| Runtime | NODE\|20-lts |

**To set the startup command:**
```bash
az webapp config set -g anna-booktable-rg -n anna-booktable-frontend --startup-file "node server.cjs"
```

---

## 6. Deploying the Monitor Tool

**Location:** `tools/monitor/`
**Runtime:** NODE|20-lts
**Startup command:** `node server.js`

```bash
cd tools/monitor
npm install
az webapp up --name booktable-monitor --resource-group anna-booktable-rg --runtime "NODE:20-lts" --sku F1
```

Or use the zip deploy approach (same as frontend, minus the Vite build).

### Monitor App Settings

| Setting | Value |
|---------|-------|
| POSTGRES_URL | `postgresql://booktable_admin:AzureDev2026!@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require` |
| REDIS_URL | `anna-booktable-redis.redis.cache.windows.net:6380,password=<key>,ssl=True` |
| AZURE_SERVICEBUS_CONNECTIONSTRING | `Endpoint=sb://anna-booktable-bus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>` |
| SCM_DO_BUILD_DURING_DEPLOYMENT | true |

---

## 7. Database Setup (Azure PostgreSQL)

**Server:** `anna-booktable-pg.postgres.database.azure.com`
**Port:** 5432
**Database:** `booktable`
**Admin:** `booktable_admin` / `AzureDev2026!`
**SSL:** Required

### Run Schema and Seed Data

From a machine with `psql` or through the local Docker PostgreSQL as a client:

```bash
# Option A: Direct psql (if installed locally)
psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/01_schema.sql
psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/02_seed_data.sql

# Option B: Through Docker container as psql client
# Use stdin pipe (NOT -f flag — Git Bash on Windows translates /tmp paths)
docker exec -i booktable-postgres psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/01_schema.sql
docker exec -i booktable-postgres psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/02_seed_data.sql
```

### Seed Data Summary

- 61 Bellevue-area restaurants with operating hours
- 336 tables across all restaurants
- ~72,912 time slots (11:00–21:00, 90-min intervals, 30 days)
- 5 test users (Anna = `e0000000-0000-0000-0000-000000000001`)
- Restaurant policies (hold duration, cancellation, overbooking)

---

## 8. Azure App Settings Reference

### Connection Strings (shared by Search, Inventory, Reservation, Payment)

```
ConnectionStrings__PostgreSQL = Host=anna-booktable-pg.postgres.database.azure.com;Port=5432;Database=booktable;Username=booktable_admin;Password=AzureDev2026!;SslMode=Require;Trust Server Certificate=true
ConnectionStrings__Redis = anna-booktable-redis.redis.cache.windows.net:6380,password=<REDIS_KEY>,ssl=True,abortConnect=False
```

### Gateway (anna-booktable-gateway)

| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| ALLOWED_ORIGINS | https://anna-booktable-frontend.azurewebsites.net |
| ServiceUrls__Search | https://anna-booktable-search.azurewebsites.net |
| ServiceUrls__Inventory | https://anna-booktable-inventory.azurewebsites.net |
| ServiceUrls__Reservations | https://anna-booktable-reservation.azurewebsites.net |
| ServiceUrls__Payments | https://anna-booktable-payment.azurewebsites.net |
| ReverseProxy__Clusters__search__Destinations__default__Address | https://anna-booktable-search.azurewebsites.net |
| ReverseProxy__Clusters__inventory__Destinations__default__Address | https://anna-booktable-inventory.azurewebsites.net |
| ReverseProxy__Clusters__reservations__Destinations__default__Address | https://anna-booktable-reservation.azurewebsites.net |
| ReverseProxy__Clusters__payments__Destinations__default__Address | https://anna-booktable-payment.azurewebsites.net |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 0 |

### Search (anna-booktable-search)

| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| ConnectionStrings__PostgreSQL | *(see above)* |
| ConnectionStrings__Redis | *(see above)* |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 1 |
| WEBSITES_CONTAINER_START_TIME_LIMIT | 600 |

### Inventory (anna-booktable-inventory)

Same as Search.

### Reservation (anna-booktable-reservation)

Same as Search, plus:
| Setting | Value |
|---------|-------|
| ServiceUrls__Inventory | https://anna-booktable-inventory.azurewebsites.net |
| ServiceUrls__Payments | https://anna-booktable-payment.azurewebsites.net |

### Payment (anna-booktable-payment)

| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| ConnectionStrings__PostgreSQL | *(see above)* |
| ConnectionStrings__Redis | *(see above)* |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 1 |
| WEBSITES_CONTAINER_START_TIME_LIMIT | 600 |

### Frontend (anna-booktable-frontend)

| Setting | Value |
|---------|-------|
| Startup command | `node server.cjs` |
| WEBSITES_PORT | 8080 |
| SCM_DO_BUILD_DURING_DEPLOYMENT | **false** |
| WEBSITES_ENABLE_APP_SERVICE_STORAGE | true |
| WEBSITE_WEBDEPLOY_USE_SCM | false |

### Monitor (anna-booktable-monitor)

| Setting | Value |
|---------|-------|
| Startup command | `node server.js` |
| POSTGRES_URL | `postgresql://booktable_admin:AzureDev2026!@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require` |
| REDIS_URL | `anna-booktable-redis.redis.cache.windows.net:6380,password=<key>,ssl=True` |
| AZURE_SERVICEBUS_CONNECTIONSTRING | `Endpoint=sb://anna-booktable-bus.servicebus.windows.net/;...` |
| SCM_DO_BUILD_DURING_DEPLOYMENT | true |

---

## 9. Pitfalls & Lessons Learned

These cost hours of debugging. Read them before deploying.

### NEVER use PowerShell `Compress-Archive` for Linux deployments

PowerShell creates zip entries with **backslash** paths (`dist\assets\index.js`).
On Linux, backslash is a valid filename character, not a path separator.
This creates files literally named `assets\index.js` in the root directory instead of
`assets/index.js` in a subdirectory. The app then can't find its files and crashes.

**Always use** Node.js `archiver`, `7z`, `tar`, or any non-PowerShell tool.

### `SCM_DO_BUILD_DURING_DEPLOYMENT` breaks Node.js apps

Azure's Oryx build for Node creates a symlink `node_modules → /node_modules`,
but `/node_modules` can end up empty. This causes `require('express')` to fail silently.

**Fix:** Set `SCM_DO_BUILD_DURING_DEPLOYMENT=false` and include `node_modules` in your zip.

### ASPNETCORE_ENVIRONMENT must be set explicitly

Without `ASPNETCORE_ENVIRONMENT=Development`, .NET services won't load
`appsettings.Development.json` and will have no connection strings.

### Git Bash `/tmp` path translation

Git Bash on Windows translates `/tmp/` paths to `C:/Users/.../Temp/`.
When running commands like `docker exec -f /tmp/file.sql`, the path gets mangled.
**Fix:** Use stdin pipe (`< file.sql`) instead of `-f` flag.

### DB init scripts only run once

Docker `docker-entrypoint-initdb.d` scripts only execute on first container creation.
If the volume already exists (from a previous `docker compose up`), the scripts are skipped.
You must run them manually if you need to re-initialize.

### Redis `AbortOnConnectFail`

Default Redis connection in .NET throws on startup if Redis is down.
Always set `AbortOnConnectFail = false` in `ConfigurationOptions`.

### Minimal API query params are required by default

`int partySize` in a Minimal API endpoint is **required**. If the client omits it,
the request fails with 400. Use `int? partySize` and apply defaults manually.

### Npgsql DateOnly UTC

`DateOnly.ToDateTime(TimeOnly)` creates `DateTimeKind.Unspecified`.
For `timestamptz` columns, use `DateOnly.ToDateTime(time, DateTimeKind.Utc)`.

### Container start time limit

Set `WEBSITES_CONTAINER_START_TIME_LIMIT=600` for .NET services — they can take
up to a minute to start on cold boot with the B1 plan.

### Kudu API for remote debugging

When you can't SSH into the container, use the Kudu REST API:
```bash
az rest --method post \
  --url "https://{app-name}.scm.azurewebsites.net/api/command" \
  --body '{"command":"ls -la /home/site/wwwroot/","dir":"/home/site"}' \
  --resource "https://management.azure.com/"
```

This lets you run arbitrary commands, check file contents, install packages, etc.

---

## 10. Troubleshooting

### Site returns 503 / container keeps restarting

1. **Download logs:**
   ```bash
   az webapp log download -g anna-booktable-rg -n {app-name} --log-file logs.zip
   ```
2. **Check Kudu for file layout:**
   ```bash
   az rest --method post \
     --url "https://{app-name}.scm.azurewebsites.net/api/command" \
     --body '{"command":"ls -la /home/site/wwwroot/","dir":"/home/site"}' \
     --resource "https://management.azure.com/"
   ```
3. **Check if node_modules has express (frontend):**
   ```bash
   az rest --method post \
     --url "https://anna-booktable-frontend.scm.azurewebsites.net/api/command" \
     --body '{"command":"node -e \"require.resolve('express')\"","dir":"/home/site/wwwroot"}' \
     --resource "https://management.azure.com/"
   ```
4. **Nuclear option — clean and redeploy:**
   ```bash
   az rest --method post \
     --url "https://{app-name}.scm.azurewebsites.net/api/command" \
     --body '{"command":"rm -rf /home/site/wwwroot/*","dir":"/home/site"}' \
     --resource "https://management.azure.com/"
   # Then redeploy
   ```

### Frontend builds but shows blank page

- Check browser console for 404s on `/assets/index-*.js`
- Likely cause: backslash paths in zip (see Pitfall #1)
- Verify with Kudu: `ls -la /home/site/wwwroot/dist/assets/`

### Gateway returns 502 for API calls

- Check the downstream service is actually running: `curl https://anna-booktable-{service}.azurewebsites.net/health`
- Check YARP routing config in Gateway app settings
- The Gateway needs both `ServiceUrls__*` AND `ReverseProxy__Clusters__*` settings

---

## 11. Cleanup

```bash
# Delete everything (irreversible!)
az group delete -n anna-booktable-rg --yes --no-wait
```
