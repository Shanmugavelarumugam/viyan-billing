import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/item_model.dart';
import '../models/order_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreRepositoryProvider = Provider((ref) => FirestoreRepository());

class FirestoreRepository {

  // Check if Firebase is initialized safely
  bool get isInitialized {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore? get _db {
    if (!isInitialized) return null;
    return FirebaseFirestore.instance;
  }

  FirebaseAuth? get _auth {
    if (!isInitialized) return null;
    return FirebaseAuth.instance;
  }

  String? get uid => _auth?.currentUser?.uid;

  // --- SHOP PROFILE SYNC ---

  Future<void> saveShopProfile(ShopModel shop) async {
    final db = _db;
    if (uid == null || db == null) return;
    
    await db.collection('users').doc(uid).collection('shops').doc('profile').set({
      'name': shop.name,
      'upiId': shop.upiId,
      'address': shop.address,
      'email': shop.email,
      'ownerName': shop.ownerName,
      'shopType': shop.shopType,
      'currency': shop.currency,
      'tokenStartNumber': shop.tokenStartNumber,
      'isCashEnabled': shop.isCashEnabled,
      'isUpiEnabled': shop.isUpiEnabled,
      'language': shop.language,
      'subscriptionPlan': shop.subscriptionPlan,
      'subscriptionExpiry': shop.subscriptionExpiry?.toIso8601String(),
      'profilePhotoPath': shop.profilePhotoPath,
      'phone': shop.phone,
      'gstNumber': shop.gstNumber,
      'logoPath': shop.logoPath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<ShopModel?> getShopProfile() async {
    final db = _db;
    if (uid == null || db == null) return null;

    final doc = await db.collection('users').doc(uid).collection('shops').doc('profile').get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return ShopModel(
      name: data['name'] ?? '',
      upiId: data['upiId'],
      address: data['address'],
      email: data['email'],
      ownerName: data['ownerName'],
      shopType: data['shopType'],
      currency: data['currency'],
      language: data['language'] ?? 'en',
      tokenStartNumber: data['tokenStartNumber'],
      isCashEnabled: data['isCashEnabled'],
      isUpiEnabled: data['isUpiEnabled'],
      subscriptionPlan: data['subscriptionPlan'],
      subscriptionExpiry: data['subscriptionExpiry'] != null 
          ? DateTime.tryParse(data['subscriptionExpiry']) 
          : null,
      profilePhotoPath: data['profilePhotoPath'],
      phone: data['phone'],
      gstNumber: data['gstNumber'],
      logoPath: data['logoPath'],
    );
  }

  // --- ITEMS SYNC ---

  Future<void> saveItem(ItemModel item) async {
    final db = _db;
    if (uid == null || db == null) return;

    await db.collection('users').doc(uid).collection('items').doc(item.id).set({
      'name': item.name,
      'price': item.price,
      'category': item.category,
      'isAvailable': item.isAvailable,
      'imageUrl': item.imageUrl,
      'costPrice': item.costPrice,
      'barcode': item.barcode,
      'stockCount': item.stockCount,
      'trackStock': item.trackStock,
      'lowStockThreshold': item.lowStockThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deductStockTransactionally(Map<String, double> stockUpdates) async {
    final db = _db;
    if (uid == null || db == null) return;

    await db.runTransaction((transaction) async {
      for (final entry in stockUpdates.entries) {
        final itemId = entry.key;
        final deductQty = entry.value;

        final docRef = db.collection('users').doc(uid).collection('items').doc(itemId);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          final data = doc.data()!;
          final trackStock = data['trackStock'] ?? false;
          if (trackStock) {
            final currentStock = (data['stockCount'] ?? 0.0) as num;
            final newStock = (currentStock - deductQty).clamp(0.0, double.infinity);
            transaction.update(docRef, {
              'stockCount': newStock,
            });
          }
        }
      }
    });
  }

  Future<void> deleteItem(String itemId) async {
    final db = _db;
    if (uid == null || db == null) return;
    await db.collection('users').doc(uid).collection('items').doc(itemId).delete();
  }
  Stream<List<ItemModel>> getItemsStream() {
    final db = _db;
    if (uid == null || db == null) return Stream.value([]);

    return db.collection('users').doc(uid).collection('items')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ItemModel(
          id: doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          category: data['category'],
          isAvailable: data['isAvailable'] ?? true,
          imageUrl: data['imageUrl'],
          costPrice: data['costPrice'] != null ? (data['costPrice'] as num).toDouble() : null,
          barcode: data['barcode'],
          stockCount: data['stockCount'] != null ? (data['stockCount'] as num).toDouble() : 0.0,
          trackStock: data['trackStock'] ?? false,
          lowStockThreshold: data['lowStockThreshold'] ?? 5,
        );
      }).toList();
    });
  }

  Future<List<ItemModel>> getItemsOnce() async {
    final db = _db;
    if (uid == null || db == null) return [];

    final snapshot = await db.collection('users').doc(uid).collection('items').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ItemModel(
        id: doc.id,
        name: data['name'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        category: data['category'],
        isAvailable: data['isAvailable'] ?? true,
        imageUrl: data['imageUrl'],
        costPrice: data['costPrice'] != null ? (data['costPrice'] as num).toDouble() : null,
        barcode: data['barcode'],
        stockCount: data['stockCount'] != null ? (data['stockCount'] as num).toDouble() : 0.0,
        trackStock: data['trackStock'] ?? false,
        lowStockThreshold: data['lowStockThreshold'] ?? 5,
      );
    }).toList();
  }

  // --- ORDERS / BILLS SYNC ---

  Future<void> saveOrder(OrderModel order) async {
    final db = _db;
    if (uid == null || db == null) return;

    await db.collection('users').doc(uid).collection('orders').doc(order.id).set({
      'tokenNumber': order.tokenNumber,
      'total': order.total,
      'timestamp': order.timestamp.toIso8601String(),
      'paymentMethod': order.paymentMethod,
      'customerPhone': order.customerPhone,
      'items': order.items.map((i) => {
        'name': i.item.name,
        'price': i.item.price,
        'quantity': i.quantity,
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<OrderModel>> getOrdersOnce() async {
    final db = _db;
    if (uid == null || db == null) return [];

    final snapshot = await db.collection('users').doc(uid).collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(100) // Adjust limit as needed
        .get();
        
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return OrderModel(
        id: doc.id,
        tokenNumber: data['tokenNumber'] ?? 0,
        total: (data['total'] ?? 0.0).toDouble(),
        timestamp: DateTime.parse(data['timestamp']),
        paymentMethod: data['paymentMethod'] ?? 'Cash',
        customerPhone: data['customerPhone'],
        items: (data['items'] as List).map((i) => CartItemModel(
          item: ItemModel(id: '', name: i['name'], price: (i['price'] ?? 0.0).toDouble()),
          quantity: i['quantity'] ?? 1,
        )).toList(),
      );
    }).toList();
  }

  // --- DEVICE TRIAL CHECK & REGISTRATION ---

  Future<Map<String, dynamic>?> checkAndRegisterDeviceTrial(String deviceId, String email) async {
    final db = _db;
    if (db == null) return null;

    final docRef = db.collection('trial_devices').doc(deviceId);
    final doc = await docRef.get();

    final now = DateTime.now();

    // Debug logging during device trial check
    debugPrint('Email: $email');
    debugPrint('DeviceId: $deviceId');
    debugPrint('Doc exists: ${doc.exists}');

    if (!doc.exists) {
      final trialData = {
        'deviceId': deviceId,
        'firstEmail': email,
        'trialStartedAt': now.toIso8601String(),
        'trialEndsAt': now.add(const Duration(days: 15)).toIso8601String(),
        'isBlocked': false,
      };
      await docRef.set(trialData);
      return trialData;
    } else {
      final data = doc.data();
      final existingEmail = data?['firstEmail'] as String?;
      debugPrint('Firestore email: $existingEmail');
      return data;
    }
  }
}
