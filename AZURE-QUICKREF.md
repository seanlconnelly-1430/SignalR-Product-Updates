# Quick Reference - Azure Deployment

## Prerequisites Check
```bash
# Check Azure CLI
az --version

# Check Docker
docker --version

# Login to Azure
az login

# Set subscription
az account set --subscription "<subscription-id>"
```

## One-Command Deployment
```bash
./deploy-azure.sh
```

## Manual Step-by-Step Commands

### 1. Create Resources
```bash
# Resource Group
az group create --name signalr-rg --location eastus

# Container Registry
az acr create --resource-group signalr-rg --name signalracr --sku Basic --admin-enabled true

# Get ACR credentials
az acr credential show --name signalracr

# Container Apps Environment
az containerapp env create --name signalr-env --resource-group signalr-rg --location eastus
```

### 2. Build & Push Images
```bash
# Login to ACR
az acr login --name signalracr

# Build and push server
cd ProductUpdatesServer
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-server:latest .
docker push signalracr.azurecr.io/signalr-server:latest
cd ..

# Build and push client (after updating environment.azure.ts with server URL)
cd product-updates-client
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .
docker push signalracr.azurecr.io/signalr-client:latest
cd ..
```

### 3. Deploy Applications
```bash
# Deploy server
az containerapp create \
  --name signalr-server \
  --resource-group signalr-rg \
  --environment signalr-env \
  --image signalracr.azurecr.io/signalr-server:latest \
  --registry-server signalracr.azurecr.io \
  --registry-username signalracr \
  --registry-password "<from step 1>" \
  --target-port 5170 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars ASPNETCORE_ENVIRONMENT=Production

# Get server URL
az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv

# Deploy client (after updating environment.azure.ts)
az containerapp create \
  --name signalr-client \
  --resource-group signalr-rg \
  --environment signalr-env \
  --image signalracr.azurecr.io/signalr-client:latest \
  --registry-server signalracr.azurecr.io \
  --registry-username signalracr \
  --registry-password "<from step 1>" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.25 \
  --memory 0.5Gi

# Get client URL
az containerapp show --name signalr-client --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv
```

## Update Commands

### Update Server
```bash
# After code changes
cd ProductUpdatesServer
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-server:latest .
docker push signalracr.azurecr.io/signalr-server:latest

# Deploy update
az containerapp update --name signalr-server --resource-group signalr-rg --image signalracr.azurecr.io/signalr-server:latest
```

### Update Client
```bash
# After code changes
cd product-updates-client
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .
docker push signalracr.azurecr.io/signalr-client:latest

# Deploy update
az containerapp update --name signalr-client --resource-group signalr-rg --image signalracr.azurecr.io/signalr-client:latest
```

## Monitoring Commands

### View Logs
```bash
# Server logs (follow)
az containerapp logs show --name signalr-server --resource-group signalr-rg --follow

# Client logs (follow)
az containerapp logs show --name signalr-client --resource-group signalr-rg --follow

# Last 100 lines
az containerapp logs show --name signalr-server --resource-group signalr-rg --tail 100
```

### Check Status
```bash
# Server status
az containerapp show --name signalr-server --resource-group signalr-rg --query properties.runningStatus

# Client status
az containerapp show --name signalr-client --resource-group signalr-rg --query properties.runningStatus

# Get all details
az containerapp show --name signalr-server --resource-group signalr-rg
```

### Health Checks
```bash
# Get URLs
SERVER_URL=$(az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)
CLIENT_URL=$(az containerapp show --name signalr-client --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)

# Test health endpoints
curl https://$SERVER_URL/health
curl https://$CLIENT_URL/health
```

## Scaling Commands

### Manual Scaling
```bash
# Scale server
az containerapp update --name signalr-server --resource-group signalr-rg --min-replicas 2 --max-replicas 5

# Scale client
az containerapp update --name signalr-client --resource-group signalr-rg --min-replicas 2 --max-replicas 5
```

### Scale to Zero (Stop)
```bash
# Stop server
az containerapp update --name signalr-server --resource-group signalr-rg --min-replicas 0 --max-replicas 0

# Stop client
az containerapp update --name signalr-client --resource-group signalr-rg --min-replicas 0 --max-replicas 0
```

### Resume (Scale Up)
```bash
# Resume server
az containerapp update --name signalr-server --resource-group signalr-rg --min-replicas 1 --max-replicas 3

# Resume client
az containerapp update --name signalr-client --resource-group signalr-rg --min-replicas 1 --max-replicas 3
```

## Resource Management

### List Resources
```bash
# All resources in group
az resource list --resource-group signalr-rg --output table

# Container apps
az containerapp list --resource-group signalr-rg --output table

# Images in registry
az acr repository list --name signalracr --output table
```

### Delete Resources
```bash
# Delete specific container app
az containerapp delete --name signalr-server --resource-group signalr-rg --yes

# Delete entire resource group (everything)
az group delete --name signalr-rg --yes --no-wait
```

## Troubleshooting Commands

### View Revision History
```bash
# Server revisions
az containerapp revision list --name signalr-server --resource-group signalr-rg --output table

# Client revisions
az containerapp revision list --name signalr-client --resource-group signalr-rg --output table
```

### Restart Application
```bash
# Restart server
az containerapp revision restart --name signalr-server --resource-group signalr-rg

# Restart client
az containerapp revision restart --name signalr-client --resource-group signalr-rg
```

### Check Build Logs
```bash
# ACR build logs
az acr task logs --name signalracr --registry signalracr
```

## Cost Management

### Check Costs
```bash
# Current month costs
az consumption usage list --start-date $(date -u +%Y-%m-01) --output table

# Estimated monthly cost
az consumption budget list --resource-group signalr-rg
```

### Set Budget Alert
```bash
az consumption budget create \
  --resource-group signalr-rg \
  --budget-name signalr-budget \
  --amount 50 \
  --time-grain Monthly \
  --start-date $(date -u +%Y-%m-01) \
  --end-date 2025-12-31
```

## Environment URLs

After deployment, save these for quick access:

```bash
# Get and display URLs
echo "Server: https://$(az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)"
echo "Client: https://$(az containerapp show --name signalr-client --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)"
echo "Server Health: https://$(az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)/health"
echo "Client Health: https://$(az containerapp show --name signalr-client --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)/health"
```

## Quick Tests

```bash
# Test server API
SERVER_URL=https://$(az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)

# Health check
curl $SERVER_URL/health

# Get products
curl $SERVER_URL/api/products

# Add product
curl -X POST $SERVER_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","price":99.99}'
```

## Useful Aliases

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Azure SignalR aliases
alias az-signalr-logs-server='az containerapp logs show --name signalr-server --resource-group signalr-rg --follow'
alias az-signalr-logs-client='az containerapp logs show --name signalr-client --resource-group signalr-rg --follow'
alias az-signalr-status='az containerapp list --resource-group signalr-rg --output table'
alias az-signalr-urls='echo "Server: https://$(az containerapp show --name signalr-server --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)" && echo "Client: https://$(az containerapp show --name signalr-client --resource-group signalr-rg --query properties.configuration.ingress.fqdn -o tsv)"'
alias az-signalr-delete='az group delete --name signalr-rg --yes --no-wait'
```
