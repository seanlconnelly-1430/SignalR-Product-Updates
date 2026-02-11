# Azure Container Apps Deployment Guide

This guide walks through deploying the SignalR Product Updates application to Azure Container Apps.

## Prerequisites

- Azure CLI installed: `brew install azure-cli` (macOS)
- Azure subscription
- Docker installed and running

## Architecture

The application consists of two containers:
- **signalr-server**: ASP.NET Core backend with SignalR hub (port 5170)
- **signalr-client**: Angular frontend served by Nginx (port 80)

## Step 1: Login to Azure

```bash
az login
```

Set your subscription (if you have multiple):
```bash
az account set --subscription "<your-subscription-id>"
```

## Step 2: Create Resource Group

```bash
az group create \
  --name signalr-rg \
  --location eastus
```

## Step 3: Create Azure Container Registry (ACR)

```bash
az acr create \
  --resource-group signalr-rg \
  --name signalracr \
  --sku Basic \
  --location eastus
```

Enable admin access:
```bash
az acr update \
  --name signalracr \
  --admin-enabled true
```

Get credentials:
```bash
az acr credential show --name signalracr
```

## Step 4: Login to ACR

```bash
az acr login --name signalracr
```

## Step 5: Build and Push Server Image

From the project root:

```bash
cd ProductUpdatesServer
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-server:latest .
docker push signalracr.azurecr.io/signalr-server:latest
cd ..
```

## Step 6: Build and Push Client Image

```bash
cd product-updates-client
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .
docker push signalracr.azurecr.io/signalr-client:latest
cd ..
```

## Step 7: Create Container Apps Environment

```bash
az containerapp env create \
  --name signalr-env \
  --resource-group signalr-rg \
  --location eastus
```

## Step 8: Deploy Server Container

```bash
az containerapp create \
  --name signalr-server \
  --resource-group signalr-rg \
  --environment signalr-env \
  --image signalracr.azurecr.io/signalr-server:latest \
  --registry-server signalracr.azurecr.io \
  --registry-username signalracr \
  --registry-password "<password-from-step-3>" \
  --target-port 5170 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1Gi \
  --env-vars ASPNETCORE_ENVIRONMENT=Production
```

Get the server URL:
```bash
az containerapp show \
  --name signalr-server \
  --resource-group signalr-rg \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

**Note the URL** - you'll need it for the next step!

## Step 9: Update Client Environment with Actual Server URL

Before deploying the client, update the environment file with the actual server URL:

Edit `product-updates-client/src/environments/environment.azure.ts`:
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://<actual-server-fqdn>',
  signalRUrl: 'https://<actual-server-fqdn>/productHub'
};
```

Rebuild and push the client image:
```bash
cd product-updates-client
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .
docker push signalracr.azurecr.io/signalr-client:latest
cd ..
```

## Step 10: Deploy Client Container

```bash
az containerapp create \
  --name signalr-client \
  --resource-group signalr-rg \
  --environment signalr-env \
  --image signalracr.azurecr.io/signalr-client:latest \
  --registry-server signalracr.azurecr.io \
  --registry-username signalracr \
  --registry-password "<password-from-step-3>" \
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.25 \
  --memory 0.5Gi
```

Get the client URL:
```bash
az containerapp show \
  --name signalr-client \
  --resource-group signalr-rg \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

## Step 11: Verify Deployment

Visit the client URL in your browser. The application should:
1. Load the Angular UI
2. Connect to the SignalR hub (check browser console)
3. Allow adding/updating/deleting products with real-time updates

## Step 12: Monitor and Logs

View server logs:
```bash
az containerapp logs show \
  --name signalr-server \
  --resource-group signalr-rg \
  --follow
```

View client logs:
```bash
az containerapp logs show \
  --name signalr-client \
  --resource-group signalr-rg \
  --follow
```

## Updating the Application

To update either container:

1. Make your code changes
2. Rebuild the Docker image with the same tag
3. Push to ACR
4. Update the container app:

```bash
az containerapp update \
  --name signalr-server \
  --resource-group signalr-rg \
  --image signalracr.azurecr.io/signalr-server:latest
```

Or for the client:
```bash
az containerapp update \
  --name signalr-client \
  --resource-group signalr-rg \
  --image signalracr.azurecr.io/signalr-client:latest
```

## Scaling

Auto-scaling is configured by default (1-3 replicas). To modify:

```bash
az containerapp update \
  --name signalr-server \
  --resource-group signalr-rg \
  --min-replicas 2 \
  --max-replicas 5
```

## Cost Management

Container Apps uses consumption-based pricing. To minimize costs:

```bash
# Stop a container app (sets replicas to 0)
az containerapp update \
  --name signalr-server \
  --resource-group signalr-rg \
  --min-replicas 0 \
  --max-replicas 0
```

## Cleanup

To delete all resources:

```bash
az group delete --name signalr-rg --yes --no-wait
```

## Troubleshooting

### CORS Errors
- Verify the client URL is added to AllowedOrigins in appsettings.Production.json
- Check that *.azurecontainerapps.io is allowed in Program.cs CORS policy

### SignalR Connection Failed
- Verify the server is running: `curl https://<server-fqdn>/health`
- Check that WebSocket is enabled (Container Apps enables this by default)
- Review server logs for connection errors

### Application Not Loading
- Check client health: `curl https://<client-fqdn>/health`
- Verify Nginx configuration is correct
- Check that the Angular build was successful

## Security Considerations

For production deployments, consider:

1. **Use Managed Identity**: Replace registry username/password with managed identity
2. **Enable HTTPS Only**: Already configured via external ingress
3. **API Keys/Authentication**: Add authentication to your API endpoints
4. **Network Security**: Use Virtual Network integration for private communication
5. **Secrets Management**: Use Azure Key Vault for sensitive configuration

## Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [ASP.NET Core SignalR on Azure](https://learn.microsoft.com/en-us/aspnet/core/signalr/scale)
- [Container Apps Pricing](https://azure.microsoft.com/en-us/pricing/details/container-apps/)
