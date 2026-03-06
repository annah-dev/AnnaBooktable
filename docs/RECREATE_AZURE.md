# AnnaBooktable — Recreate Azure Infrastructure from Scratch

> All Azure resources were deleted on 2026-03-05 to eliminate charges.
> This document has the exact commands to recreate everything.
> See `AZURE_DEPLOYMENT.md` for app settings and deployment steps after recreation.

## Resource Group (already exists, free)

```bash
az group create -n anna-booktable-rg -l westus2
```

## 1. PostgreSQL Flexible Server (~$25/mo)

```bash
az postgres flexible-server create \
  -g anna-booktable-rg \
  -n anna-booktable-pg \
  -l centralus \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 16 \
  --storage-size 32 \
  --admin-user booktable_admin \
  --admin-password 'AzureDev2026!' \
  --public-access 0.0.0.0-255.255.255.255 \
  --yes
```

Then create the database and load schema + seed data:
```bash
# Install psql or use Docker container as client
psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=postgres user=booktable_admin password=AzureDev2026! sslmode=require" -c "CREATE DATABASE booktable;"

psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/01_schema.sql
psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/init/02_seed_data.sql

# Optional: add extra tables
psql "host=anna-booktable-pg.postgres.database.azure.com port=5432 dbname=booktable user=booktable_admin password=AzureDev2026! sslmode=require" < db/add_tables.sql
```

**Connection string for app settings:**
```
Host=anna-booktable-pg.postgres.database.azure.com;Port=5432;Database=booktable;Username=booktable_admin;Password=AzureDev2026!;SslMode=Require;Trust Server Certificate=true
```

## 2. Redis Cache (~$16/mo)

```bash
az redis create \
  -g anna-booktable-rg \
  -n anna-booktable-redis \
  -l westus2 \
  --sku Basic \
  --vm-size C0
```

This takes 15-20 minutes. Get the access key after creation:
```bash
az redis list-keys -g anna-booktable-rg -n anna-booktable-redis --query primaryKey -o tsv
```

**Connection string for app settings** (replace `<KEY>` with the key above):
```
anna-booktable-redis.redis.cache.windows.net:6380,password=<KEY>,ssl=True,abortConnect=False
```

## 3. Service Bus (~$10/mo)

```bash
az servicebus namespace create \
  -g anna-booktable-rg \
  -n anna-booktable-bus \
  -l westus2 \
  --sku Standard
```

Get the connection string:
```bash
az servicebus namespace authorization-rule keys list \
  -g anna-booktable-rg \
  --namespace-name anna-booktable-bus \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv
```

## 4. App Service Plan (~$13/mo for B1)

```bash
az appservice plan create \
  -g anna-booktable-rg \
  -n anna-booktable-plan \
  -l westus2 \
  --sku B1 \
  --is-linux
```

## 5. App Services (7 total, shared plan)

### Backend (.NET 8) services

```bash
for svc in gateway search inventory reservation payment; do
  az webapp create \
    -g anna-booktable-rg \
    -p anna-booktable-plan \
    -n anna-booktable-$svc \
    --runtime "DOTNETCORE:8.0"
done
```

### Frontend (Node 20)

```bash
az webapp create \
  -g anna-booktable-rg \
  -p anna-booktable-plan \
  -n anna-booktable-frontend \
  --runtime "NODE:20-lts"

az webapp config set \
  -g anna-booktable-rg \
  -n anna-booktable-frontend \
  --startup-file "node server.cjs"
```

### Monitor (Node 20)

```bash
az webapp create \
  -g anna-booktable-rg \
  -p anna-booktable-plan \
  -n anna-booktable-monitor \
  --runtime "NODE:20-lts"

az webapp config set \
  -g anna-booktable-rg \
  -n anna-booktable-monitor \
  --startup-file "node server.js"
```

## 6. Configure App Settings

Replace `<REDIS_KEY>` and `<SERVICEBUS_CONN>` with values from steps 2 and 3.

### All .NET services (Search, Inventory, Reservation, Payment)

```bash
PGCONN="Host=anna-booktable-pg.postgres.database.azure.com;Port=5432;Database=booktable;Username=booktable_admin;Password=AzureDev2026!;SslMode=Require;Trust Server Certificate=true"
REDISCONN="anna-booktable-redis.redis.cache.windows.net:6380,password=<REDIS_KEY>,ssl=True,abortConnect=False"

for svc in search inventory reservation payment; do
  az webapp config appsettings set -g anna-booktable-rg -n anna-booktable-$svc --settings \
    ASPNETCORE_ENVIRONMENT=Production \
    "ConnectionStrings__PostgreSQL=$PGCONN" \
    "ConnectionStrings__Redis=$REDISCONN" \
    SCM_DO_BUILD_DURING_DEPLOYMENT=false \
    WEBSITE_RUN_FROM_PACKAGE=1 \
    WEBSITES_CONTAINER_START_TIME_LIMIT=600
done
```

### Reservation (extra settings)

```bash
az webapp config appsettings set -g anna-booktable-rg -n anna-booktable-reservation --settings \
  ServiceUrls__Inventory=https://anna-booktable-inventory.azurewebsites.net \
  ServiceUrls__Payments=https://anna-booktable-payment.azurewebsites.net
```

### Gateway

```bash
az webapp config appsettings set -g anna-booktable-rg -n anna-booktable-gateway --settings \
  ASPNETCORE_ENVIRONMENT=Production \
  ALLOWED_ORIGINS=https://anna-booktable-frontend.azurewebsites.net \
  ServiceUrls__Search=https://anna-booktable-search.azurewebsites.net \
  ServiceUrls__Inventory=https://anna-booktable-inventory.azurewebsites.net \
  ServiceUrls__Reservations=https://anna-booktable-reservation.azurewebsites.net \
  ServiceUrls__Payments=https://anna-booktable-payment.azurewebsites.net \
  "ReverseProxy__Clusters__search__Destinations__default__Address=https://anna-booktable-search.azurewebsites.net" \
  "ReverseProxy__Clusters__inventory__Destinations__default__Address=https://anna-booktable-inventory.azurewebsites.net" \
  "ReverseProxy__Clusters__reservations__Destinations__default__Address=https://anna-booktable-reservation.azurewebsites.net" \
  "ReverseProxy__Clusters__payments__Destinations__default__Address=https://anna-booktable-payment.azurewebsites.net" \
  SCM_DO_BUILD_DURING_DEPLOYMENT=false
```

### Frontend

```bash
az webapp config appsettings set -g anna-booktable-rg -n anna-booktable-frontend --settings \
  WEBSITES_PORT=8080 \
  SCM_DO_BUILD_DURING_DEPLOYMENT=false \
  WEBSITES_ENABLE_APP_SERVICE_STORAGE=true
```

### Monitor

```bash
az webapp config appsettings set -g anna-booktable-rg -n anna-booktable-monitor --settings \
  "POSTGRES_URL=postgresql://booktable_admin:AzureDev2026!@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require" \
  "REDIS_URL=anna-booktable-redis.redis.cache.windows.net:6380,password=<REDIS_KEY>,ssl=True" \
  "AZURE_SERVICEBUS_CONNECTIONSTRING=<SERVICEBUS_CONN>" \
  SCM_DO_BUILD_DURING_DEPLOYMENT=false
```

## 7. Deploy Code

See `docs/AZURE_DEPLOYMENT.md` for full details. Quick summary:

```bash
# Backend services (from repo root)
dotnet publish src/Gateway/AnnaBooktable.Gateway.csproj -c Release -o publish/gateway
dotnet publish src/Services/SearchService/AnnaBooktable.SearchService.csproj -c Release -o publish/search
dotnet publish src/Services/InventoryService/AnnaBooktable.InventoryService.csproj -c Release -o publish/inventory
dotnet publish src/Services/ReservationService/AnnaBooktable.ReservationService.csproj -c Release -o publish/reservation
dotnet publish src/Services/PaymentService/AnnaBooktable.PaymentService.csproj -c Release -o publish/payment

# Zip each (NEVER use PowerShell Compress-Archive)
cd src/diner-app
node -e "const a=require('archiver');const s=['gateway','search','inventory','reservation','payment'];s.forEach(svc=>{const o=require('fs').createWriteStream('../../deploy-'+svc+'.zip');const ar=a('zip',{zlib:{level:6}});ar.pipe(o);ar.directory('../../publish/'+svc+'/',false);o.on('close',()=>console.log(svc+': '+(ar.pointer()/1024/1024).toFixed(1)+' MB'));ar.finalize()})"

# Deploy each
for svc in gateway search inventory reservation payment; do
  az webapp deploy -g anna-booktable-rg -n anna-booktable-$svc \
    --src-path deploy-$svc.zip --type zip --clean true
done

# Frontend
cd src/diner-app
npm run build && node bundle-deploy.mjs
az webapp deploy -g anna-booktable-rg -n anna-booktable-frontend \
  --src-path D:/Dev/AnnaBooktable/frontend-deploy.zip --type zip --clean true

# Monitor
cd tools/monitor
az webapp up --name anna-booktable-monitor -g anna-booktable-rg --runtime "NODE:20-lts"
# Then fix node_modules:
az rest --method post \
  --url "https://anna-booktable-monitor.scm.azurewebsites.net/api/command" \
  --body '{"command":"npm install --omit=dev","dir":"/home/site/wwwroot"}' \
  --resource "https://management.azure.com/"
az webapp restart -g anna-booktable-rg -n anna-booktable-monitor
```

## 8. Verify

```bash
curl https://anna-booktable-gateway.azurewebsites.net/health
# Expected: {"status":"healthy","services":{"search":"up","inventory":"up","reservations":"up","payments":"up"}}

curl -sI https://anna-booktable-frontend.azurewebsites.net/
# Expected: HTTP 200

curl -sI https://anna-booktable-monitor.azurewebsites.net/
# Expected: HTTP 200
```

## What Was Deleted

| Resource | Type | SKU | Location | Monthly Cost |
|----------|------|-----|----------|-------------|
| anna-booktable-redis | Azure Cache for Redis | Basic C0 | West US 2 | ~$16 |
| anna-booktable-bus | Service Bus Namespace | Standard | West US 2 | ~$10 |
| anna-booktable-plan | App Service Plan (Linux) | B1 | West US 2 | ~$13 |
| anna-booktable-gateway | App Service (DOTNETCORE\|8.0) | shared plan | West US 2 | — |
| anna-booktable-search | App Service (DOTNETCORE\|8.0) | shared plan | West US 2 | — |
| anna-booktable-inventory | App Service (DOTNETCORE\|8.0) | shared plan | West US 2 | — |
| anna-booktable-reservation | App Service (DOTNETCORE\|8.0) | shared plan | West US 2 | — |
| anna-booktable-payment | App Service (DOTNETCORE\|8.0) | shared plan | West US 2 | — |
| anna-booktable-frontend | App Service (NODE\|20-lts) | shared plan | West US 2 | — |
| anna-booktable-monitor | App Service (NODE\|20-lts) | shared plan | West US 2 | — |
| anna-booktable-pg | PostgreSQL Flexible Server | Standard_B1ms | Central US | ~$25 (+ ~$1 storage) |
| workspace-annabooktablerge4nK | Log Analytics Workspace | — | West US 2 | ~$0 |
| anna-booktable-env | Container App Environment | — | West US 2 | ~$0 |

**Total deleted monthly cost: ~$65/mo**

## What Was Kept

| Resource | Type | Monthly Cost |
|----------|------|-------------|
| anna-booktable-rg | Resource Group | $0 (free) |

## Data Recovery

All application data can be recreated from:
- `db/init/01_schema.sql` — database schema
- `db/init/02_seed_data.sql` — 60 restaurants, 326 tables, users, time slots
- `db/add_tables.sql` — additional tables (326 → 799)

Reservations made by users/agents will be lost. Everything else is reproducible.
