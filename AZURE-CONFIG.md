# Azure Configuration Summary

This document summarizes all the Azure-specific configurations added to the SignalR Product Updates application.

## Files Created for Azure Deployment

### 1. Server Azure Dockerfile
**File**: `ProductUpdatesServer/Dockerfile.azure`
- Multi-stage build with .NET 10.0 SDK and runtime
- Health check endpoint configured
- Sets `ASPNETCORE_ENVIRONMENT=Production`
- Exposes port 5170

### 2. Client Azure Dockerfile
**File**: `product-updates-client/Dockerfile.azure`
- Accepts `BUILD_CONFIGURATION` build argument (defaults to `azure`)
- Multi-stage build with Node 23-alpine and Nginx
- Health check endpoint at `/health`
- Uses custom nginx.azure.conf configuration
- Optimized for production with gzip compression

### 3. Nginx Azure Configuration
**File**: `product-updates-client/nginx.azure.conf`
- Health check endpoint at `/health`
- Security headers (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection)
- Gzip compression enabled
- Static asset caching (1 year)
- SPA routing support (all routes serve index.html)

### 4. Azure Environment Configuration
**File**: `product-updates-client/src/environments/environment.azure.ts`
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://signalr-server.azurecontainerapps.io',
  signalRUrl: 'https://signalr-server.azurecontainerapps.io/productHub'
};
```

### 5. Docker Environment Configuration
**File**: `product-updates-client/src/environments/environment.docker.ts`
```typescript
export const environment = {
  production: true,
  apiUrl: 'http://server:5170',
  signalRUrl: 'http://server:5170/productHub'
};
```

### 6. Production Settings
**File**: `ProductUpdatesServer/appsettings.Production.json`
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.AspNetCore.SignalR": "Information"
    }
  },
  "AllowedOrigins": [
    "https://signalr-client.azurecontainerapps.io"
  ]
}
```

## Code Modifications for Azure

### 1. Health Check Endpoint
**File**: `ProductUpdatesServer/Program.cs`

Added:
```csharp
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
   .WithName("HealthCheck")
   .AllowAnonymous();
```

### 2. Dynamic CORS for Azure
**File**: `ProductUpdatesServer/Program.cs` (already configured)

The CORS policy automatically allows:
- All `*.azurecontainerapps.io` domains in production
- Configured origins from `appsettings.json`
- WebSocket upgrade for SignalR

### 3. Angular Build Configurations
**File**: `product-updates-client/angular.json`

Added configurations:
```json
"azure": {
  "fileReplacements": [
    {
      "replace": "src/environments/environment.ts",
      "with": "src/environments/environment.azure.ts"
    }
  ],
  "optimization": true,
  "outputHashing": "all",
  "sourceMap": false,
  "namedChunks": false,
  "aot": true,
  "extractLicenses": true,
  "buildOptimizer": true
}
```

## Deployment Automation

### Automated Deployment Script
**File**: `deploy-azure.sh`

Features:
- Checks prerequisites (Azure CLI, Docker)
- Creates all required Azure resources
- Builds and pushes Docker images to ACR
- Updates client environment with actual server URL
- Deploys both containers to Azure Container Apps
- Displays final URLs and health check endpoints
- Provides logging commands for troubleshooting

Usage:
```bash
chmod +x deploy-azure.sh
./deploy-azure.sh
```

### Manual Deployment Guide
**File**: `AZURE.md`

Complete step-by-step instructions including:
- Prerequisites and setup
- Resource creation commands
- Image building and pushing
- Container deployment
- Monitoring and logging
- Scaling configuration
- Cost management
- Troubleshooting guide
- Security considerations

## Azure Resources Created

The deployment creates the following Azure resources:

1. **Resource Group**: `signalr-rg`
   - Location: East US
   - Contains all other resources

2. **Container Registry**: `signalracr`
   - SKU: Basic
   - Admin enabled for authentication
   - Stores Docker images

3. **Container Apps Environment**: `signalr-env`
   - Shared environment for both apps
   - Manages networking and logging

4. **Server Container App**: `signalr-server`
   - Image: `signalracr.azurecr.io/signalr-server:latest`
   - CPU: 0.5 cores
   - Memory: 1 GiB
   - Replicas: 1-3 (auto-scaling)
   - Port: 5170
   - External ingress enabled
   - Environment: Production

5. **Client Container App**: `signalr-client`
   - Image: `signalracr.azurecr.io/signalr-client:latest`
   - CPU: 0.25 cores
   - Memory: 0.5 GiB
   - Replicas: 1-3 (auto-scaling)
   - Port: 80
   - External ingress enabled

## Environment Variable Strategy

### Development (`environment.ts`)
- Uses `localhost:5170`
- For local development with `ng serve` and `dotnet run`

### Docker (`environment.docker.ts`)
- Uses `http://server:5170`
- Server container name as hostname
- For Docker Compose deployments

### Azure (`environment.azure.ts`)
- Uses `https://signalr-server.azurecontainerapps.io`
- Azure Container Apps FQDN
- Updated automatically by deployment script

### Production (`environment.prod.ts`)
- Generic production configuration
- Updated to match Azure configuration

## Build Commands

### Build for Azure
```bash
# Client
cd product-updates-client
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .

# Server
cd ProductUpdatesServer
docker build -f Dockerfile.azure -t signalracr.azurecr.io/signalr-server:latest .
```

### Build for Docker Compose
```bash
docker-compose build
```

### Build for Development
```bash
# Client
cd product-updates-client
npm install
ng serve

# Server
cd ProductUpdatesServer
dotnet restore
dotnet run
```

## Health Checks

Both applications expose health check endpoints:

- **Server**: `https://signalr-server.azurecontainerapps.io/health`
  - Returns: `{"status":"healthy","timestamp":"2024-01-01T00:00:00Z"}`
  
- **Client**: `https://signalr-client.azurecontainerapps.io/health`
  - Returns: `healthy` (plain text)

Azure Container Apps uses these endpoints to:
- Monitor application health
- Restart unhealthy containers
- Route traffic only to healthy instances

## Monitoring

### View Logs
```bash
# Server logs
az containerapp logs show \
  --name signalr-server \
  --resource-group signalr-rg \
  --follow

# Client logs
az containerapp logs show \
  --name signalr-client \
  --resource-group signalr-rg \
  --follow
```

### Metrics
Available in Azure Portal:
- CPU usage
- Memory usage
- Request count
- Response time
- HTTP status codes
- Replica count

## Cost Optimization

### Auto-scaling Configuration
- Minimum replicas: 1
- Maximum replicas: 3
- Scales based on CPU and memory usage

### Cost Reduction Options
1. **Scale to zero** (testing only):
   ```bash
   az containerapp update --name signalr-server --resource-group signalr-rg --min-replicas 0 --max-replicas 0
   ```

2. **Reduce resources**:
   - Lower CPU/memory allocations
   - Use B1 tier instead of Consumption

3. **Delete when not in use**:
   ```bash
   az group delete --name signalr-rg --yes
   ```

## Security Considerations

### Current Implementation
- ✅ HTTPS enforced (Azure Container Apps default)
- ✅ CORS configured for specific origins
- ✅ Health checks implemented
- ✅ Registry credentials managed securely
- ✅ Production logging configuration

### Recommended Enhancements
- 🔲 Add authentication/authorization
- 🔲 Use Managed Identity for ACR access
- 🔲 Enable Virtual Network integration
- 🔲 Add Azure Key Vault for secrets
- 🔲 Implement rate limiting
- 🔲 Add Azure Front Door for CDN/WAF

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Verify client URL in `appsettings.Production.json`
   - Check CORS policy in `Program.cs`
   - Ensure URL includes `https://`

2. **SignalR Connection Failed**
   - Check server health: `curl https://SERVER_URL/health`
   - Verify WebSocket support (enabled by default)
   - Check server logs for connection errors

3. **Application Not Loading**
   - Check client health: `curl https://CLIENT_URL/health`
   - Verify nginx configuration
   - Check build logs in Container Registry

4. **Images Not Updating**
   - Push new image to ACR with same tag
   - Run `az containerapp update` command
   - Wait 2-3 minutes for rollout

## Next Steps

After deployment:

1. **Test the application**:
   - Open client URL in browser
   - Add/update/delete products
   - Open in multiple browsers to verify real-time updates

2. **Monitor performance**:
   - Check Azure Portal metrics
   - Review application logs
   - Monitor costs in Cost Management

3. **Customize**:
   - Update branding in Angular app
   - Add more features
   - Implement authentication
   - Add persistent database

4. **Scale**:
   - Adjust replica counts based on usage
   - Configure custom scaling rules
   - Consider Azure SignalR Service for large scale

## Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [SignalR on Azure](https://learn.microsoft.com/en-us/aspnet/core/signalr/scale)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Angular Production Build](https://angular.io/guide/deployment)
