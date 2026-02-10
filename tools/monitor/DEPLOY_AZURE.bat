@echo off
title Anna's Booktable Monitor - Azure Deploy
echo.
echo  ╔═══════════════════════════════════════════╗
echo  ║   Deploy Monitor to Azure App Service      ║
echo  ╚═══════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:: Check Azure CLI
where az >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Azure CLI not found. Install from https://aka.ms/installazurecli
    pause
    exit /b 1
)

:: Verify login
az account show >nul 2>nul
if errorlevel 1 (
    echo [INFO] Not logged in. Running az login...
    az login
)

set RG=anna-booktable-rg
set APP=booktable-monitor
set REGION=westus2

echo [1/4] Creating App Service (if needed)...
az webapp up --name %APP% --resource-group %RG% --runtime "NODE:18-lts" --sku F1 --location %REGION%

echo.
echo [2/4] Configuring WebSocket support...
az webapp config set --name %APP% --resource-group %RG% --web-sockets-enabled true

echo.
echo [3/4] Setting connection strings...
echo.
echo  You need to set these App Settings in the Azure Portal or CLI.
echo  Replace the placeholder values with your actual Azure resource connection strings:
echo.
echo    POSTGRES_URL=postgresql://booktable_admin:PASSWORD@YOUR-SERVER.postgres.database.azure.com:5432/booktable?sslmode=require
echo    REDIS_URL=YOUR-REDIS.redis.cache.windows.net:6380,password=YOUR-KEY,ssl=True
echo    AZURE_SERVICEBUS_CONNECTIONSTRING=Endpoint=sb://YOUR-BUS.servicebus.windows.net/;SharedAccessKeyName=...
echo.
echo  Or if still using RabbitMQ on a VM:
echo    RABBITMQ_URL=amqp://guest:guest@YOUR-RABBIT-VM:5672
echo.

:: Example: uncomment and fill these in to auto-set
:: az webapp config appsettings set --name %APP% --resource-group %RG% --settings ^
::   POSTGRES_URL="postgresql://booktable_admin:PASSWORD@anna-booktable-pg.postgres.database.azure.com:5432/booktable?sslmode=require" ^
::   REDIS_URL="anna-booktable-redis.redis.cache.windows.net:6380,password=YOUR_KEY,ssl=True" ^
::   AZURE_SERVICEBUS_CONNECTIONSTRING="Endpoint=sb://anna-booktable-bus.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY"

echo [4/4] Deploying code...
az webapp up --name %APP% --resource-group %RG%

echo.
echo  ╔═══════════════════════════════════════════╗
echo  ║   Done! Dashboard at:                      ║
echo  ║   https://%APP%.azurewebsites.net      ║
echo  ╚═══════════════════════════════════════════╝
echo.
echo  Remember to configure App Settings with your
echo  Azure PostgreSQL, Redis, and Service Bus
echo  connection strings in the Azure Portal.
echo.
pause
