import '../repositories/firestore_repository.dart';
import '../models/shop_model.dart';

class ShopRepository {
  final FirestoreRepository _firestore;

  ShopRepository(this._firestore);

  Future<void> saveShopProfile(ShopModel shop) => _firestore.saveShopProfile(shop);

  Future<ShopModel?> getShopProfile() => _firestore.getShopProfile();
}
