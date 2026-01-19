import { Injectable } from '@angular/core';
import * as signalR from '@microsoft/signalr';
import { Subject } from 'rxjs';
import { Product } from '../models/product.model';

@Injectable({
  providedIn: 'root'
})
export class SignalrService {
  private hubConnection!: signalR.HubConnection;
  
  public productAdded$ = new Subject<Product>();
  public productUpdated$ = new Subject<Product>();
  public productDeleted$ = new Subject<number>();

  constructor() { }

  public startConnection(): Promise<void> {
    this.hubConnection = new signalR.HubConnectionBuilder()
      .withUrl('http://localhost:5170/productHub')
      .withAutomaticReconnect()
      .build();

    return this.hubConnection
      .start()
      .then(() => console.log('SignalR Connection started'))
      .catch(err => console.error('Error while starting connection: ' + err));
  }

  public addProductUpdateListener(): void {
    this.hubConnection.on('ReceiveProductUpdate', (product: Product) => {
      this.productUpdated$.next(product);
    });
  }

  public addProductAddedListener(): void {
    this.hubConnection.on('ProductAdded', (product: Product) => {
      this.productAdded$.next(product);
    });
  }

  public addProductDeletedListener(): void {
    this.hubConnection.on('ProductDeleted', (productId: number) => {
      this.productDeleted$.next(productId);
    });
  }

  public stopConnection(): void {
    if (this.hubConnection) {
      this.hubConnection.stop();
    }
  }
}