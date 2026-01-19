using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using ProductUpdatesServer.Hubs;
using ProductUpdatesServer.Models;

namespace ProductUpdatesServer.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly IHubContext<ProductHub> _hubContext;
        private readonly ILogger<ProductsController> _logger;
        private static List<Product> _products = new();

        public ProductsController(IHubContext<ProductHub> hubContext, ILogger<ProductsController> logger)
        {
            _hubContext = hubContext;
            _logger = logger;
        }

        [HttpGet]
        public ActionResult<IEnumerable<Product>> GetProducts()
        {
            _logger.LogInformation("GetProducts called - Returning {Count} products", _products.Count);
            return Ok(_products);
        }

        [HttpPost]
        public async Task<ActionResult<Product>> AddProduct(Product product)
        {
            product.Id = _products.Count + 1;
            product.LastUpdated = DateTime.Now;
            _products.Add(product);

            _logger.LogInformation("Product added: Id={Id}, Name={Name}, Price={Price}", product.Id, product.Name, product.Price);
            _logger.LogInformation("Broadcasting ProductAdded to all SignalR clients...");
            await _hubContext.Clients.All.SendAsync("ProductAdded", product);
            _logger.LogInformation("ProductAdded broadcast complete");
            return CreatedAtAction(nameof(GetProducts), new { id = product.Id }, product);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateProduct(int id, Product product)
        {
            var existingProduct = _products.FirstOrDefault(p => p.Id == id);
            if (existingProduct == null)
            {
                _logger.LogWarning("Update failed: Product with Id={Id} not found", id);
                return NotFound();
            }

            existingProduct.Name = product.Name;
            existingProduct.Price = product.Price;
            existingProduct.Description = product.Description;
            existingProduct.LastUpdated = DateTime.Now;

            _logger.LogInformation("Product updated: Id={Id}, Name={Name}, Price={Price}", id, existingProduct.Name, existingProduct.Price);
            await _hubContext.Clients.All.SendAsync("ReceiveProductUpdate", existingProduct);
            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteProduct(int id)
        {
            var product = _products.FirstOrDefault(p => p.Id == id);
            if (product == null)
            {
                _logger.LogWarning("Delete failed: Product with Id={Id} not found", id);
                return NotFound();
            }

            _products.Remove(product);
            _logger.LogInformation("Product deleted: Id={Id}, Name={Name}", id, product.Name);
            await _hubContext.Clients.All.SendAsync("ProductDeleted", id);
            return NoContent();
        }
    }
}