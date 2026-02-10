# AnnaBooktable Azure Deployment

## Infrastructure Overview

| Component | Azure Service | Name | Region | SKU |
|-----------|--------------|------|--------|-----|
| Database | PostgreSQL Flexible Server | anna-booktable-pg | Central US | Standard_B1ms (Burstable) |
| Cache | Azure Cache for Redis | anna-booktable-redis | West US 2 | Basic C0 |
| Compute | App Service Plan (Linux) | anna-booktable-plan | West US 2 | B1 |
| Gateway | App Service | anna-booktable-gateway | West US 2 | (shared plan) |
| Search API | App Service | anna-booktable-search | West US 2 | (shared plan) |
| Inventory API | App Service | anna-booktable-inventory | West US 2 | (shared plan) |
| Reservation API | App Service | anna-booktable-reservation | West US 2 | (shared plan) |
| Payment API | App Service | anna-booktable-payment | West US 2 | (shared plan) |
| Frontend | App Service (Node 20) | anna-booktable-frontend | West US 2 | (shared plan) |

## URLs

| Service | URL |
|---------|-----|
| Frontend | https://anna-booktable-frontend.azurewebsites.net |
| Gateway (API) | https://anna-booktable-gateway.azurewebsites.net |
| Health Check | https://anna-booktable-gateway.azurewebsites.net/health |

## Connection Strings

Connection strings are configured as Azure App Settings (not stored in code).
See Azure Portal > App Service > Configuration for actual values.

## App Settings by Service

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
| WEBSITE_RUN_FROM_PACKAGE | 1 |

### Search, Inventory (anna-booktable-search, anna-booktable-inventory)
| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| ConnectionStrings__PostgreSQL | (see above) |
| ConnectionStrings__Redis | (see above) |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 1 |

### Reservation (anna-booktable-reservation)
| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| ConnectionStrings__PostgreSQL | (see above) |
| ConnectionStrings__Redis | (see above) |
| ServiceUrls__Inventory | https://anna-booktable-inventory.azurewebsites.net |
| ServiceUrls__Payments | https://anna-booktable-payment.azurewebsites.net |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 1 |

### Payment (anna-booktable-payment)
| Setting | Value |
|---------|-------|
| ASPNETCORE_ENVIRONMENT | Production |
| SCM_DO_BUILD_DURING_DEPLOYMENT | false |
| WEBSITE_RUN_FROM_PACKAGE | 1 |

### Frontend (anna-booktable-frontend)
| Setting | Value |
|---------|-------|
| Startup command | node server.js |
| VITE_API_URL (build-time) | https://anna-booktable-gateway.azurewebsites.net |

## Architecture

```
[Frontend SPA] --> [Gateway (YARP Reverse Proxy)]
                        |
        +-------+-------+-------+-------+
        |       |               |       |
    [Search] [Inventory]  [Reservation] [Payment]
        |       |               |       |
        +---[PostgreSQL]---+    |       |
        +---[Redis Cache]--+---/       /
                                      /
    (MassTransit: in-memory, no RabbitMQ on Azure)
```

## Deployment Commands

### Publish and Deploy a Service
```bash
# Publish
dotnet publish src/Services/SearchService/AnnaBooktable.SearchService.csproj -c Release -o publish/search

# Zip (PowerShell)
Compress-Archive -Path 'publish\search\*' -DestinationPath 'deploy-search.zip' -Force

# Deploy
az webapp deployment source config-zip -g anna-booktable-rg -n anna-booktable-search --src deploy-search.zip --timeout 600
```

### Deploy Frontend
```bash
cd src/diner-app
VITE_API_URL=https://anna-booktable-gateway.azurewebsites.net npm run build
# Copy server.js into dist/
Compress-Archive -Path 'dist\*' -DestinationPath 'deploy-frontend.zip' -Force
az webapp deployment source config-zip -g anna-booktable-rg -n anna-booktable-frontend --src deploy-frontend.zip --timeout 600
```

### Run Schema/Seed on Azure PostgreSQL
```bash
# Use connection string from Azure Portal
docker exec -i booktable-postgres psql "$AZURE_PG_CONN" < db/init/01_schema.sql
docker exec -i booktable-postgres psql "$AZURE_PG_CONN" < db/init/02_seed_data.sql
```

## Cleanup
```bash
az group delete -n anna-booktable-rg --yes --no-wait
```
