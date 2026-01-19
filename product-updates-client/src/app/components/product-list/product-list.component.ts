import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { Product } from '../../models/product.model';
import { ProductService } from '../../services/product.service';
import { SignalrService } from '../../services/signalr.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-product-list',
  standalone: false,
  templateUrl: './product-list.component.html',
  styleUrls: ['./product-list.component.css']
})
export class ProductListComponent implements OnInit, OnDestroy {
  products: Product[] = [];
  newProduct: Product = { id: 0, name: '', price: 0, description: '', lastUpdated: new Date() };
  
  private subscriptions: Subscription[] = [];

  constructor(
    private productService: ProductService,
    private signalrService: SignalrService,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit(): void {
    this.loadProducts();
    this.startSignalRConnection();
  }

  ngOnDestroy(): void {
    this.subscriptions.forEach(sub => sub.unsubscribe());
    this.signalrService.stopConnection();
  }

  private startSignalRConnection(): void {
    this.signalrService.startConnection().then(() => {
      this.signalrService.addProductAddedListener();
      this.signalrService.addProductUpdateListener();
      this.signalrService.addProductDeletedListener();

      this.subscriptions.push(
        this.signalrService.productAdded$.subscribe(product => {
          console.log('Product added:', product);
          this.products.push(product);
          this.cdr.detectChanges();
        })
      );

      this.subscriptions.push(
        this.signalrService.productUpdated$.subscribe(product => {
          console.log('Product updated:', product);
          const index = this.products.findIndex(p => p.id === product.id);
          if (index !== -1) {
            this.products[index] = product;
            this.cdr.detectChanges();
          }
        })
      );

      this.subscriptions.push(
        this.signalrService.productDeleted$.subscribe(productId => {
          console.log('Product deleted:', productId);
          this.products = this.products.filter(p => p.id !== productId);
          this.cdr.detectChanges();
        })
      );
    });
  }

  loadProducts(): void {
    this.productService.getProducts().subscribe(products => {
      this.products = products;
    });
  }

  addProduct(): void {
    this.productService.addProduct(this.newProduct).subscribe(() => {
      this.newProduct = { id: 0, name: '', price: 0, description: '', lastUpdated: new Date() };
    });
  }

  updateProduct(product: Product): void {
    this.productService.updateProduct(product.id, product).subscribe();
  }

  deleteProduct(id: number): void {
    this.productService.deleteProduct(id).subscribe();
  }
}