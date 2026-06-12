import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/shop_model.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../../data/repositories/firestore_repository.dart';
import '../../auth/providers/auth_provider.dart';

final shopRepositoryProvider = Provider((ref) {
  final firestore = ref.watch(firestoreRepositoryProvider);
  return ShopRepository(firestore);
});

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
  final firestore = ref.watch(firestoreRepositoryProvider);
  return ShopNotifier(
    ref.watch(shopRepositoryProvider),
    firestore,
    authState.isAuthenticated,
  );
});

class ShopNotifier extends StateNotifier<ShopState> {
  final ShopRepository _shopRepository;
  final FirestoreRepository _firestoreRepository;
  final bool isAuthenticated;

  ShopNotifier(this._shopRepository, this._firestoreRepository, this.isAuthenticated) : super(ShopState()) {
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
      final cloudShop = await _shopRepository.getShopProfile();
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
    
    // Get/Generate unique Device ID
    final settingsBox = Hive.box('settings_box');
    String? deviceId = settingsBox.get('device_id');
    if (deviceId == null) {
      final random = Random.secure();
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      deviceId = List.generate(24, (index) => chars[random.nextInt(chars.length)]).join();
      await settingsBox.put('device_id', deviceId);
    }
    
    ShopModel updatedShop = shop;
    
    // Check and register device trial in Firestore
    try {
      final email = shop.email ?? 'unknown@example.com';
      final trialData = await _firestoreRepository.checkAndRegisterDeviceTrial(deviceId, email);
      
      if (trialData != null) {
        final firstEmail = trialData['firstEmail'] as String?;
        final trialEndsAtStr = trialData['trialEndsAt'] as String?;
        final isBlocked = trialData['isBlocked'] as bool? ?? false;
        
        final trialEndsAt = trialEndsAtStr != null ? DateTime.tryParse(trialEndsAtStr) : null;
        
        if (isBlocked) {
          // Blocked device
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Expired',
            subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)),
          );
        } else if (firstEmail != null && firstEmail != email) {
          // Trial Abuse! Different email on same device -> immediately expired subscription
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Expired (Suspicious)',
            subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)),
          );
        } else {
          // Valid trial or user returning
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Free Trial',
            subscriptionExpiry: trialEndsAt ?? DateTime.now().add(const Duration(days: 15)),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Device trial check failed: $e");
    }

    await box.clear(); // Only one shop profile
    await box.add(updatedShop);
    if (mounted) {
      state = ShopState(shop: updatedShop, isLoaded: true);
    }
    
    // Sync with Firestore (Try-catch to handle offline or configuration issues)
    try {
      await _shopRepository.saveShopProfile(updatedShop);
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
