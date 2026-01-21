# Docker Setup for SignalR Product Updates

## Running with Docker Compose

### Prerequisites
- Docker Desktop installed
- Docker Compose installed (included with Docker Desktop)

### Quick Start

1. **Build and start all containers**:
```bash
cd /Users/seanconnelly/Documents/repos/SignalR
docker-compose up --build
```

2. **Access the applications**:
   - **Angular Client**: http://localhost:4200
   - **ASP.NET Core Server**: http://localhost:5170

3. **Stop the containers**:
```bash
docker-compose down
```

### Container Architecture

```
┌─────────────────────┐         Docker Network          ┌─────────────────────┐
│  Angular Client     │         (signalr-network)       │  ASP.NET Core       │
│  Container: client  │◄──────────────────────────────►│  Container: server  │
│  Port: 4200:80      │                                 │  Port: 5170:5170    │
│  Nginx + Angular    │                                 │  .NET 8 Runtime     │
└─────────────────────┘                                 └─────────────────────┘
```

### Individual Container Commands

**Build and run server only**:
```bash
cd ProductUpdatesServer
docker build -t signalr-server .
docker run -p 5170:5170 signalr-server
```

**Build and run client only**:
```bash
cd product-updates-client
docker build -t signalr-client .
docker run -p 4200:80 signalr-client
```

### Docker Compose Configuration

The `docker-compose.yml` defines:
- **server**: ASP.NET Core API with SignalR
- **client**: Angular application served by Nginx
- **signalr-network**: Bridge network for inter-container communication

### Environment Configuration

The applications use different URLs based on environment:

**Development (local)**:
- API: `http://localhost:5170/api`
- SignalR: `http://localhost:5170/productHub`

**Docker (production)**:
- API: `http://server:5170/api`
- SignalR: `http://server:5170/productHub`

### Troubleshooting

**Check container logs**:
```bash
docker-compose logs server
docker-compose logs client
```

**Rebuild without cache**:
```bash
docker-compose build --no-cache
docker-compose up
```

**Remove all containers and images**:
```bash
docker-compose down --rmi all
```

**Access container shell**:
```bash
docker exec -it signalr-server /bin/bash
docker exec -it signalr-client /bin/sh
```

### Network Communication

Containers communicate using Docker's internal DNS:
- Server is accessible at `http://server:5170` within the network
- Client can reach server using the container name `server`
- CORS is configured to accept requests from both `localhost` and container names

### File Structure

```
SignalR/
├── docker-compose.yml                    # Orchestrates both containers
├── ProductUpdatesServer/
│   ├── Dockerfile                        # Server container definition
│   └── .dockerignore                     # Files to exclude from build
└── product-updates-client/
    ├── Dockerfile                        # Client container definition
    ├── nginx.conf                        # Nginx configuration
    └── .dockerignore                     # Files to exclude from build
```

### Health Checks

**Check if server is running**:
```bash
curl http://localhost:5170/api/products
```

**Check if client is accessible**:
```bash
curl http://localhost:4200
```

### Production Considerations

For production deployment:
1. Use environment variables for URLs
2. Enable HTTPS with SSL certificates
3. Configure proper logging
4. Set up health checks
5. Use a reverse proxy (e.g., Nginx, Traefik)
6. Implement proper secrets management
7. Configure resource limits in docker-compose.yml

### Scaling

To run multiple client instances:
```bash
docker-compose up --scale client=3
```

Note: You'll need to configure a load balancer for multiple instances.
