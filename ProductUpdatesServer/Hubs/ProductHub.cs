using Microsoft.AspNetCore.SignalR;
using ProductUpdatesServer.Models;

namespace ProductUpdatesServer.Hubs
{
    public class ProductHub : Hub
    {
        private readonly ILogger<ProductHub> _logger;

        public ProductHub(ILogger<ProductHub> logger)
        {
            _logger = logger;
        }

        public override async Task OnConnectedAsync()
        {
            _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            _logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
            await base.OnDisconnectedAsync(exception);
        }

        public async Task SendProductUpdate(Product product)
        {
            await Clients.All.SendAsync("ReceiveProductUpdate", product);
        }

        public async Task NotifyProductAdded(Product product)
        {
            await Clients.All.SendAsync("ProductAdded", product);
        }

        public async Task NotifyProductDeleted(int productId)
        {
            await Clients.All.SendAsync("ProductDeleted", productId);
        }
    }
}