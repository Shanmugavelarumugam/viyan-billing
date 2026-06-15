import '../repositories/firestore_repository.dart';
import '../models/order_model.dart';
import '../models/item_model.dart';

class BillingRepository {
  final FirestoreRepository _firestore;

  BillingRepository(this._firestore, _);

  Future<void> saveOrder(OrderModel order) => _firestore.saveOrder(order);
  
  Future<List<OrderModel>> getOrders() => _firestore.getOrdersOnce();

  Future<void> saveItem(ItemModel item) => _firestore.saveItem(item);

  Future<void> deductStockTransactionally(Map<String, double> stockUpdates) =>
      _firestore.deductStockTransactionally(stockUpdates);

  Future<void> deleteItem(String id) => _firestore.deleteItem(id);

  Future<List<ItemModel>> getItems() => _firestore.getItemsOnce();

  Stream<List<ItemModel>> getItemsStream() => _firestore.getItemsStream();
}
