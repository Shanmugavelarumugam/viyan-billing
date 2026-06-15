import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final isAuthenticated = ref.watch(authProvider.select((a) => a.isAuthenticated));
  final firestore = ref.watch(firestoreRepositoryProvider);
  return ShopNotifier(
    ref.watch(shopRepositoryProvider),
    firestore,
    isAuthenticated,
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
    final uid = _firestoreRepository.uid;
    
    if (uid != null && box.containsKey(uid)) {
      localShop = box.get(uid);
      debugPrint("📦 Local shop found for UID $uid: ${localShop?.name}");
      if (mounted) {
        state = state.copyWith(shop: localShop, isLoaded: true);
      }
    } else {
      debugPrint("📦 No local shop found for UID $uid. Will wait for cloud fetch.");
    }
    
    // Always attempt to sync with latest from cloud on startup
    try {
      debugPrint("☁️ Attempting to fetch shop from cloud...");
      final cloudShop = await _shopRepository.getShopProfile();
      if (!mounted) return;

      if (cloudShop != null) {
        debugPrint("☁️ Cloud shop found: ${cloudShop.name}. Overwriting local.");
        
        ShopModel mergedShop = cloudShop;
        if (localShop != null && cloudShop.subscriptionExpiry == null) {
          debugPrint("⚠️ Cloud expiry null. Keeping local subscription values.");
          mergedShop = cloudShop.copyWith(
            subscriptionPlan: localShop.subscriptionPlan,
            subscriptionExpiry: localShop.subscriptionExpiry,
          );
        }

        if (uid != null) {
          await box.put(uid, mergedShop);
        }
        if (mounted) {
          state = ShopState(shop: mergedShop, isLoaded: true);
        }
      } else {
        debugPrint("☁️ No cloud shop found.");
        if (mounted) {
          state = ShopState(shop: null, isLoaded: true);
        }
      }
    } catch (e) {
      debugPrint("❌ Cloud sync error: $e");
      if (mounted) {
        state = state.copyWith(isLoaded: true);
      }
    }
  }

  Future<void> saveShop(ShopModel shop) async {
    final box = Hive.box<ShopModel>('shop_box');
    
    // Get/Generate unique Device ID
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: true,
      ),
    );
    String? deviceId;
    try {
      deviceId = await secureStorage.read(key: 'device_id');
    } catch (e) {
      debugPrint("⚠️ Secure storage read failed: $e");
    }

    if (deviceId == null || deviceId.isEmpty) {
      final random = Random.secure();
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      deviceId = List.generate(24, (index) => chars[random.nextInt(chars.length)]).join();
      try {
        await secureStorage.write(key: 'device_id', value: deviceId);
      } catch (e) {
        debugPrint("⚠️ Secure storage write failed: $e");
      }
    }
    
    debugPrint('ℹ️ saveShop deviceId: $deviceId');
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
        
        debugPrint('ℹ️ trialEndsAtStr: $trialEndsAtStr');
        debugPrint('ℹ️ parsed trialEndsAt: $trialEndsAt');
        
        if (isBlocked) {
          // Blocked device
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Expired',
            subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)),
          );
        } else if (firstEmail != null &&
            firstEmail != 'unknown@example.com' &&
            email != 'unknown@example.com' &&
            firstEmail.trim().toLowerCase() != email.trim().toLowerCase()) {
          // Trial Abuse! Different email on same device -> immediately expired subscription
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Expired (Suspicious)',
            subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)),
          );
        } else {
          // Valid trial or user returning
          updatedShop = shop.copyWith(
            subscriptionPlan: 'Free Trial',
            subscriptionExpiry: trialEndsAt ??
                shop.subscriptionExpiry ??
                DateTime.now().add(const Duration(days: 15)),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Device trial check failed: $e");
    }

    // Robust safeguard: Ensure subscriptionExpiry is never null for Free Trial
    if (updatedShop.subscriptionPlan == 'Free Trial' && updatedShop.subscriptionExpiry == null) {
      debugPrint("⚠️ subscriptionExpiry was null for Free Trial. Setting default 15-day expiry.");
      updatedShop = updatedShop.copyWith(
        subscriptionExpiry: DateTime.now().add(const Duration(days: 15)),
      );
    }

    debugPrint('✅ Final Expiry: ${updatedShop.subscriptionExpiry}');

    final uid = _firestoreRepository.uid;
    if (uid != null) {
      await box.put(uid, updatedShop);
    } else {
      await box.clear();
      await box.add(updatedShop);
    }
    if (mounted) {
      state = ShopState(shop: updatedShop, isLoaded: true);
    }
    
    debugPrint('========= SHOP SAVE =========');
    debugPrint('Plan: ${updatedShop.subscriptionPlan}');
    debugPrint('Expiry: ${updatedShop.subscriptionExpiry}');
    debugPrint('============================');
    
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
    final uid = _firestoreRepository.uid;
    if (uid != null) {
      await box.delete(uid);
    } else {
      await box.clear();
    }
    if (mounted) {
      state = ShopState(shop: null, isLoaded: true);
    }
  }
}
