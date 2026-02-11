# SignalR Product Updates - Real-Time Application

A full-stack real-time product management application demonstrating bidirectional communication between an ASP.NET Core backend and an Angular frontend using SignalR.

## Overview

This application enables multiple clients to view and manage products with real-time synchronization. When one user adds, updates, or deletes a product, all connected clients instantly see the changes without refreshing the page.

## Architecture

### High-Level Architecture

```
┌─────────────────┐         SignalR          ┌─────────────────┐
│  Angular Client │◄──────WebSocket─────────►│ ASP.NET Core    │
│  (Port 62871)   │         HTTP             │ Server          │
│                 │◄──────REST API──────────►│ (Port 5170)     │
└─────────────────┘                          └─────────────────┘
```

### Communication Flow

1. **HTTP REST API**: Client makes HTTP requests for CRUD operations
2. **SignalR Hub**: Server broadcasts changes to all connected clients via WebSocket
3. **Real-Time Updates**: All clients receive and display updates immediately

---

## Server Architecture (ASP.NET Core)

### Technology Stack
- **Framework**: ASP.NET Core 8.0+
- **Real-Time**: SignalR
- **Language**: C# 12
- **Data Storage**: In-memory List (demo purposes)

### Project Structure

```
ProductUpdatesServer/
├── Controllers/
│   └── ProductsController.cs       # REST API endpoints
├── Hubs/
│   └── ProductHub.cs               # SignalR hub for real-time communication
├── Models/
│   └── Product.cs                  # Product data model
└── Program.cs                       # Application configuration
```

### Key Components

#### 1. ProductHub (SignalR Hub)
**Location**: `Hubs/ProductHub.cs`

**Purpose**: Manages WebSocket connections and enables real-time communication

**Features**:
- Tracks client connections/disconnections
- Provides hub methods for broadcasting messages
- Logs connection events

**Key Methods**:
- `OnConnectedAsync()`: Logs when a client connects
- `OnDisconnectedAsync()`: Logs when a client disconnects
- `SendProductUpdate()`: Broadcasts product updates
- `NotifyProductAdded()`: Broadcasts new product additions
- `NotifyProductDeleted()`: Broadcasts product deletions

#### 2. ProductsController (REST API)
**Location**: `Controllers/ProductsController.cs`

**Purpose**: Handles HTTP CRUD operations and triggers SignalR broadcasts

**Endpoints**:
- `GET /api/products` - Retrieve all products
- `POST /api/products` - Add new product (broadcasts to all clients)
- `PUT /api/products/{id}` - Update product (broadcasts to all clients)
- `DELETE /api/products/{id}` - Delete product (broadcasts to all clients)

**Key Features**:
- Injects `IHubContext<ProductHub>` to broadcast from controller
- Logs all operations to console
- Uses `Clients.All.SendAsync()` to notify all connected clients

#### 3. Product Model
**Location**: `Models/Product.cs`

```csharp
public class Product
{
    public int Id { get; set; }
    public string Name { get; set; }
    public decimal Price { get; set; }
    public string Description { get; set; }
    public DateTime LastUpdated { get; set; }
}
```

#### 4. Program.cs Configuration

**Services Registered**:
- `AddSignalR()`: Enables SignalR
- `AddControllers()`: Enables REST API
- `AddCors()`: Configures cross-origin requests

**CORS Policy**:
```csharp
policy.WithOrigins("http://localhost:4200", "http://localhost:62871")
      .AllowAnyHeader()
      .AllowAnyMethod()
      .AllowCredentials();
```

**Endpoints**:
- `/api/products` → ProductsController
- `/productHub` → SignalR Hub

---

## Client Architecture (Angular)

### Technology Stack
- **Framework**: Angular 19
- **Real-Time**: @microsoft/signalr
- **Language**: TypeScript
- **HTTP Client**: HttpClient
- **State Management**: RxJS Subjects

### Project Structure

```
product-updates-client/src/app/
├── components/
│   └── product-list/
│       ├── product-list.component.ts       # Main component
│       ├── product-list.component.html     # Template
│       └── product-list.component.css      # Styles
├── services/
│   ├── signalr.service.ts                  # SignalR connection management
│   └── product.service.ts                  # HTTP API calls
├── models/
│   └── product.model.ts                    # Product interface
├── app.component.ts                        # Root component
├── app.module.ts                           # NgModule configuration
└── app.html                                # Root template
```

### Key Components

#### 1. SignalrService
**Location**: `services/signalr.service.ts`

**Purpose**: Manages SignalR connection and real-time events

**Key Features**:
- Establishes WebSocket connection to `/productHub`
- Uses RxJS Subjects to emit events
- Automatic reconnection on disconnect
- Provides observables for product events

**Public API**:
```typescript
startConnection(): Promise<void>
addProductAddedListener(): void
addProductUpdateListener(): void
addProductDeletedListener(): void
stopConnection(): void

// Observables
productAdded$: Subject<Product>
productUpdated$: Subject<Product>
productDeleted$: Subject<number>
```

**Connection Setup**:
```typescript
this.hubConnection = new signalR.HubConnectionBuilder()
  .withUrl('http://localhost:5170/productHub')
  .withAutomaticReconnect()
  .build();
```

#### 2. ProductService
**Location**: `services/product.service.ts`

**Purpose**: Handles HTTP communication with REST API

**Methods**:
- `getProducts()`: GET all products
- `addProduct(product)`: POST new product
- `updateProduct(id, product)`: PUT update product
- `deleteProduct(id)`: DELETE product

**Base URL**: `http://localhost:5170/api/products`

#### 3. ProductListComponent
**Location**: `components/product-list/product-list.component.ts`

**Purpose**: Main UI component for displaying and managing products

**Lifecycle**:
1. `ngOnInit()`: Loads products and establishes SignalR connection
2. `ngOnDestroy()`: Cleans up subscriptions and closes SignalR connection

**Key Features**:
- Subscribes to SignalR events for real-time updates
- Uses `ChangeDetectorRef` to trigger UI updates
- Manages form for adding new products
- Displays list of all products

**Event Handling**:
```typescript
// Product Added
this.signalrService.productAdded$.subscribe(product => {
  this.products.push(product);
  this.cdr.detectChanges();
});

// Product Updated
this.signalrService.productUpdated$.subscribe(product => {
  const index = this.products.findIndex(p => p.id === product.id);
  this.products[index] = product;
  this.cdr.detectChanges();
});

// Product Deleted
this.signalrService.productDeleted$.subscribe(productId => {
  this.products = this.products.filter(p => p.id !== productId);
  this.cdr.detectChanges();
});
```

#### 4. AppModule
**Location**: `app.module.ts`

**Imports**:
- `BrowserModule`: Core Angular functionality
- `HttpClientModule`: HTTP communication
- `FormsModule`: Two-way data binding
- `RouterModule`: Routing support

---

## Real-Time Communication Flow

### Adding a Product

```
1. User fills form and clicks "Add Product"
   └─► ProductListComponent.addProduct()

2. HTTP POST to server
   └─► ProductService.addProduct()
   └─► POST http://localhost:5170/api/products

3. Server processes request
   └─► ProductsController.AddProduct()
   └─► Adds product to list
   └─► Logs to console
   └─► Broadcasts via SignalR: hubContext.Clients.All.SendAsync("ProductAdded", product)

4. All connected clients receive broadcast
   └─► SignalR connection receives "ProductAdded" event
   └─► SignalrService emits to productAdded$ Subject
   └─► ProductListComponent subscription triggered
   └─► Product added to local array
   └─► ChangeDetectorRef triggers UI update
   └─► Product appears in all windows instantly
```

### Update/Delete Flow

Similar pattern:
1. Client → HTTP request (PUT/DELETE)
2. Server → Process + Broadcast
3. All Clients → Receive + Update UI

---

## Configuration

### Server Configuration

**CORS Settings** (`Program.cs`):
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("ClientPermission", policy =>
    {
        policy.WithOrigins("http://localhost:4200", "http://localhost:62871")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
```

**SignalR Hub Mapping**:
```csharp
app.MapHub<ProductHub>("/productHub");
```

### Client Configuration

**SignalR Connection** (`signalr.service.ts`):
```typescript
.withUrl('http://localhost:5170/productHub')
.withAutomaticReconnect()
```

**API Base URL** (`product.service.ts`):
```typescript
private apiUrl = 'http://localhost:5170/api/products';
```

---

## Running the Application

### Prerequisites
- .NET SDK 8.0+
- Node.js 18+
- Angular CLI

### Start Server
```bash
cd ProductUpdatesServer
dotnet run
```
Server runs at: `http://localhost:5170`

### Start Client
```bash
cd product-updates-client
ng serve
```
Client runs at: `http://localhost:62871`

### Testing Real-Time Updates
1. Open `http://localhost:62871` in multiple browser windows
2. Add/update/delete a product in one window
3. Observe real-time updates in all windows
4. Check server terminal for logs
5. Check browser console (F12) for SignalR connection status

---

## Key Design Patterns

### Server-Side
- **Dependency Injection**: Services injected via constructor
- **Repository Pattern**: Could be extended with IProductRepository
- **Hub Pattern**: SignalR hub as message broker

### Client-Side
- **Service Pattern**: Separation of concerns (HTTP vs SignalR)
- **Observer Pattern**: RxJS Subjects for event distribution
- **Component Communication**: Services as intermediaries
- **Change Detection**: Manual change detection for SignalR events

---

## Logging and Debugging

### Server Logs
- Client connection/disconnection events
- Product CRUD operations with details
- SignalR broadcast confirmations

### Client Logs
- SignalR connection status
- Received real-time events
- Product operations

**Browser Console Messages**:
```
SignalR Connection started
Product added: {id: 1, name: "...", ...}
Product updated: {id: 1, name: "...", ...}
Product deleted: 1
```

---

## Future Enhancements

- Add persistent database (SQL Server, PostgreSQL)
- Implement authentication and authorization
- Add user-specific notifications
- Group-based broadcasting (team/organization)
- Offline support with sync on reconnect
- Product images and rich content
- Search and filtering
- Pagination for large datasets
- Unit and integration tests

---

## Deployment Options

This application can be deployed in multiple ways:

### 1. Docker Deployment (Recommended for Development)
See [DOCKER.md](DOCKER.md) for complete containerization guide.

Quick start:
```bash
docker-compose up --build
```
Access:
- Client: http://localhost
- Server: http://localhost:5170

### 2. Azure Container Apps (Production)
See [AZURE.md](AZURE.md) for complete Azure deployment guide.

Quick deploy:
```bash
./deploy-azure.sh
```

This script will:
- Create Azure resources (Resource Group, Container Registry, Container Apps Environment)
- Build and push Docker images to ACR
- Deploy both containers to Azure Container Apps
- Configure networking and health checks
- Provide URLs for both applications

Expected cost: ~$10-30/month depending on usage

### 3. Local Development
Run server and client locally (see Getting Started section).

---

## Technologies Used

### Server
- ASP.NET Core Web API
- SignalR
- ILogger for logging
- LINQ for data queries

### Client
- Angular 19
- TypeScript
- RxJS (Observables, Subjects)
- @microsoft/signalr
- Angular HttpClient
- Angular Forms

---

## License

This is a demonstration project for learning SignalR real-time communication patterns.
