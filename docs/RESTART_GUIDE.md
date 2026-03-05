# AnnaBooktable — Restart Guide

How to bring the full system back online after shutdown.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- Node.js 20+ installed
- .NET SDK installed (8.x or 10.x — project targets `net8.0`)
- Access to resource group `anna-booktable-rg`

## Quick Start (everything at once)

```bash
# Start all 7 services
az webapp start -g anna-booktable-rg -n anna-booktable-gateway
az webapp start -g anna-booktable-rg -n anna-booktable-search
az webapp start -g anna-booktable-rg -n anna-booktable-inventory
az webapp start -g anna-booktable-rg -n anna-booktable-reservation
az webapp start -g anna-booktable-rg -n anna-booktable-payment
az webapp start -g anna-booktable-rg -n anna-booktable-frontend
az webapp start -g anna-booktable-rg -n anna-booktable-monitor
```

Services take **2-4 minutes** to cold start on the B1 plan. Wait, then verify:

```bash
# Health check (tests gateway + all 4 backend services)
curl https://anna-booktable-gateway.azurewebsites.net/health
```

Expected response:
```json
{"status":"healthy","services":{"search":"up","inventory":"up","reservations":"up","payments":"up"}}
```

## Startup Order

The services can start in any order, but the recommended sequence is:

1. **Backend services first** (no dependencies between them, start in parallel):
   ```bash
   az webapp start -g anna-booktable-rg -n anna-booktable-search &
   az webapp start -g anna-booktable-rg -n anna-booktable-inventory &
   az webapp start -g anna-booktable-rg -n anna-booktable-reservation &
   az webapp start -g anna-booktable-rg -n anna-booktable-payment &
   wait
   ```

2. **Gateway** (routes traffic to backend services):
   ```bash
   az webapp start -g anna-booktable-rg -n anna-booktable-gateway
   ```

3. **Frontend** (calls APIs through the gateway):
   ```bash
   az webapp start -g anna-booktable-rg -n anna-booktable-frontend
   ```

4. **Monitor** (optional — connects to DB and Redis for live dashboard):
   ```bash
   az webapp start -g anna-booktable-rg -n anna-booktable-monitor
   ```

## Verify Each Service

```bash
# Gateway health (aggregates all backend services)
curl https://anna-booktable-gateway.azurewebsites.net/health

# Frontend (should return HTTP 200)
curl -sI https://anna-booktable-frontend.azurewebsites.net/

# Search API
curl -s "https://anna-booktable-gateway.azurewebsites.net/api/search?query=sushi&partySize=2&date=2026-03-10&time=18:00" | head -c 200

# Monitor
curl -sI https://anna-booktable-monitor.azurewebsites.net/
```

## If a Service Won't Start

### 1. Check logs
```bash
az webapp log download -g anna-booktable-rg -n anna-booktable-{service} --log-file logs.zip
```

### 2. Restart it
```bash
az webapp restart -g anna-booktable-rg -n anna-booktable-{service}
```

### 3. Check if node_modules is broken (frontend and monitor only)

The Oryx build system creates broken symlinks. If the Node.js app crashes on
startup, install dependencies directly:

```bash
az rest --method post \
  --url "https://anna-booktable-{service}.scm.azurewebsites.net/api/command" \
  --body '{"command":"npm install --omit=dev","dir":"/home/site/wwwroot"}' \
  --resource "https://management.azure.com/"
```

Then restart:
```bash
az webapp restart -g anna-booktable-rg -n anna-booktable-{service}
```

### 4. Nuclear option — redeploy

If a service is completely broken, redeploy from source. See `docs/AZURE_DEPLOYMENT.md`
for full deployment instructions.

**Backend (.NET) services:**
```bash
dotnet publish src/Services/{ServiceName}/AnnaBooktable.{ServiceName}.csproj -c Release -o publish/{svc}
# Zip with Node archiver or 7z (NEVER PowerShell Compress-Archive)
az webapp deploy -g anna-booktable-rg -n anna-booktable-{svc} --src-path deploy-{svc}.zip --type zip --clean true
```

**Frontend:**
```bash
cd src/diner-app
npm run build
node bundle-deploy.mjs
az webapp deploy -g anna-booktable-rg -n anna-booktable-frontend --src-path D:/Dev/AnnaBooktable/frontend-deploy.zip --type zip --clean true
```

## Shutdown

```bash
az webapp stop -g anna-booktable-rg -n anna-booktable-frontend
az webapp stop -g anna-booktable-rg -n anna-booktable-gateway
az webapp stop -g anna-booktable-rg -n anna-booktable-search
az webapp stop -g anna-booktable-rg -n anna-booktable-inventory
az webapp stop -g anna-booktable-rg -n anna-booktable-reservation
az webapp stop -g anna-booktable-rg -n anna-booktable-payment
az webapp stop -g anna-booktable-rg -n anna-booktable-monitor
```

## URLs

| Service | URL |
|---------|-----|
| Frontend | https://anna-booktable-frontend.azurewebsites.net |
| Gateway API | https://anna-booktable-gateway.azurewebsites.net |
| Health Check | https://anna-booktable-gateway.azurewebsites.net/health |
| Monitor | https://anna-booktable-monitor.azurewebsites.net |

## Time Slots Expiring?

The seed data generates 30 days of time slots. If slots have expired, generate new ones:

```bash
cd tools/monitor
node -e "
const{Pool}=require('pg');
const p=new Pool({connectionString:'postgresql://booktable_admin:AzureDev2026!@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require'});
p.query(\`
  INSERT INTO time_slots (restaurant_id, table_id, table_group_id, start_time, end_time, status, capacity)
  SELECT t.restaurant_id, t.table_id, t.table_group_id,
         d.day + s.slot_time, d.day + s.slot_time + INTERVAL '90 minutes', 'AVAILABLE', t.capacity
  FROM tables t
  CROSS JOIN generate_series(CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', INTERVAL '1 day') AS d(day)
  CROSS JOIN (SELECT (INTERVAL '1 hour' * h) AS slot_time FROM generate_series(11, 20) AS h) AS s
  WHERE NOT EXISTS (
    SELECT 1 FROM time_slots ts
    WHERE ts.table_id = t.table_id AND ts.start_time = d.day + s.slot_time
  )
\`).then(r=>{console.log('Inserted', r.rowCount, 'new slots');p.end()})
  .catch(e=>{console.log('ERR:',e.message);p.end()});
"
```

## Notes

- All services share one **B1 App Service Plan** — cold starts take 2-4 minutes
- PostgreSQL and Redis are always-on PaaS services (no restart needed)
- `SCM_DO_BUILD_DURING_DEPLOYMENT=false` on all services — Oryx build is disabled
- See `docs/AZURE_DEPLOYMENT.md` for the full deployment guide with all app settings
