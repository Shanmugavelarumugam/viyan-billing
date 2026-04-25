import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/shop_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

class ShopState {
  final ShopModel? shop;
  final bool isLoaded;

  ShopState({this.shop, this.isLoaded = false});

  ShopState copyWith({ShopModel? shop, bool? isLoaded}) {
    return ShopState(
      shop: shop ?? this.shop,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>((ref) {
  final authState = ref.watch(authProvider);
  return ShopNotifier(ref.watch(firestoreServiceProvider), authState.isAuthenticated);
});

class ShopNotifier extends StateNotifier<ShopState> {
  final FirestoreService _firestoreService;
  final bool isAuthenticated;

  ShopNotifier(this._firestoreService, this.isAuthenticated) : super(ShopState()) {
    if (isAuthenticated) {
      _loadShop();
    } else {
      // Not authenticated, just mark as loaded with null
      state = ShopState(shop: null, isLoaded: true);
    }
  }

  void _loadShop() async {
    final box = Hive.box<ShopModel>('shop_box');
    ShopModel? localShop;
    if (box.isNotEmpty) {
      localShop = box.getAt(0);
      debugPrint("📦 Local shop found: ${localShop?.name}");
      if (mounted) {
        state = state.copyWith(shop: localShop, isLoaded: true);
      }
    } else {
      debugPrint("📦 No local shop found.");
    }
    
    // Always attempt to sync with latest from cloud on startup
    try {
      debugPrint("☁️ Attempting to fetch shop from cloud...");
      final cloudShop = await _firestoreService.getShopProfile();
      if (!mounted) return;

      if (cloudShop != null) {
        debugPrint("☁️ Cloud shop found: ${cloudShop.name}. Overwriting local.");
        // Update local if cloud is different or local was empty
        await box.clear();
        await box.add(cloudShop);
        if (mounted) {
          state = ShopState(shop: cloudShop, isLoaded: true);
        }
      } else {
        debugPrint("☁️ No cloud shop found.");
        // No cloud shop found, if local was also empty, it's truly a new user
        if (mounted) {
          state = state.copyWith(isLoaded: true);
        }
      }
    } catch (e) {
      debugPrint("❌ Cloud sync error: $e");
      if (mounted) {
        // Offline - if we have local, we are "loaded", if not, we are also "loaded" with null
        state = state.copyWith(isLoaded: true);
      }
    }
  }

  Future<void> saveShop(ShopModel shop) async {
    final box = Hive.box<ShopModel>('shop_box');
    await box.clear(); // Only one shop profile
    await box.add(shop);
    if (mounted) {
      state = ShopState(shop: shop, isLoaded: true);
    }
    
    // Sync with Firestore (Try-catch to handle offline or configuration issues)
    try {
      await _firestoreService.saveShopProfile(shop);
    } catch (e) {
      debugPrint("⚠️ Firestore sync failed: ${e.toString()}");
    }
  }


  Future<void> updateLanguage(String languageCode) async {
    final currentShop = state.shop;
    if (currentShop == null) {
      final defaultShop = ShopModel(
        name: 'Viyan POS',
        language: languageCode,
      );
      await saveShop(defaultShop);
    } else {
      final updatedShop = currentShop.copyWith(language: languageCode);
      await saveShop(updatedShop);
    }
  }

  Future<void> clearShop() async {
    final box = Hive.box<ShopModel>('shop_box');
    await box.clear();
    if (mounted) {
      state = ShopState(shop: null, isLoaded: true);
    }
  }
}
