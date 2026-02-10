# Anna's Booktable — System Monitor

Real-time monitoring dashboard for the Booktable reservation system.
Shows the 3 defense layers (Redis holds, DB unique constraint, idempotency) in action.

Works identically on your local machine and Azure App Service.

## One-Click Start

### Windows
| File | What it does |
|------|-------------|
| `SIMULATE.bat` | Demo mode — auto-installs, opens browser, starts agents |
| `LIVE.bat` | Connects to local Docker infra (PostgreSQL, Redis, RabbitMQ) |
| `DEPLOY_AZURE.bat` | Deploys to Azure App Service in anna-booktable-rg |

### Command Line
```bash
npm start          # Simulate mode
npm run live       # Local infra (Docker Compose)
npm run azure:deploy  # Deploy to Azure
```

First run auto-installs dependencies. Opens browser automatically.

## Architecture

Single `server.js` serves both HTTP (dashboard) and WebSocket (bridge) on **one port**.
This is critical — Azure App Service only exposes one port.

```
Local:  http://localhost:3099  (WS upgrades on same port)
Azure:  https://booktable-monitor.azurewebsites.net  (wss:// auto-detected)
```

## Environment Auto-Detection

The server auto-detects where it's running:

| | Local (Docker) | Azure |
|---|---|---|
| **PostgreSQL** | `localhost:5432` | `*.postgres.database.azure.com` (SSL) |
| **Redis** | `localhost:6379` | Azure Cache for Redis (TLS :6380) |
| **Messaging** | RabbitMQ (amqplib) | Azure Service Bus (optional) |
| **Port** | 3099 | `process.env.PORT` (Azure-injected) |
| **WS** | `ws://` same port | `wss://` same port |
| **Browser** | Auto-opens | N/A (it's a URL) |

## Connection Strings

### Local defaults (zero config with Docker Compose)
```
PostgreSQL: booktable_admin:LocalDev123!@localhost:5432/booktable
Redis:      localhost:6379
RabbitMQ:   amqp://guest:guest@localhost:5672
```

### Azure (set as App Settings in Portal)
```
POSTGRES_URL=postgresql://booktable_admin:PASSWORD@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require
REDIS_URL=anna-booktable-redis.redis.cache.windows.net:6380,password=YOUR_KEY,ssl=True
AZURE_SERVICEBUS_CONNECTIONSTRING=Endpoint=sb://...  (if using Service Bus)
RABBITMQ_URL=amqp://guest:guest@YOUR-VM:5672          (if using RabbitMQ on VM)
```

## File Structure

```
booktable-monitor/
├── dashboard.html      ← Self-contained React dashboard
├── server.js           ← Unified HTTP + WS server (local + Azure)
├── setup.js            ← First-run: install deps, check infra, launch
├── package.json        ← Dependencies + scripts
├── SIMULATE.bat        ← Double-click: demo mode
├── LIVE.bat            ← Double-click: local infra
├── DEPLOY_AZURE.bat    ← Double-click: deploy to Azure
└── README.md
```
