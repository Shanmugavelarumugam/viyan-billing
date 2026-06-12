import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shop_setup/providers/shop_provider.dart';

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(SubscriptionState.initial()) {
    // Listen to shopState changes to update the subscription status
    _ref.listen<ShopState>(shopProvider, (previous, next) {
      _updateStatus(next);
    });
    // Init state with current value
    _updateStatus(_ref.read(shopProvider));
  }

  void _updateStatus(ShopState shopState) {
    final shop = shopState.shop;
    if (shop == null) {
      // Default to active for setup, or if not loaded yet
      state = SubscriptionState(isActive: true, planName: 'Free Trial');
      return;
    }

    final expiry = shop.subscriptionExpiry;
    final now = DateTime.now();
    
    if (expiry != null && expiry.isAfter(now)) {
      state = SubscriptionState(
        isActive: true,
        expiryDate: expiry,
        planName: shop.subscriptionPlan ?? 'Free Trial',
      );
    } else {
      state = SubscriptionState(
        isActive: false,
        expiryDate: expiry,
        planName: shop.subscriptionPlan ?? 'Expired',
      );
    }
  }

  void checkStatus() {
    _updateStatus(_ref.read(shopProvider));
  }

  Future<void> renewPlan(String planName, int days) async {
    final expiry = DateTime.now().add(Duration(days: days));
    state = SubscriptionState(
      isActive: true,
      expiryDate: expiry,
      planName: planName,
    );

    // Save update to Shop model
    final shop = _ref.read(shopProvider).shop;
    if (shop != null) {
      final updatedShop = shop.copyWith(
        subscriptionPlan: planName,
        subscriptionExpiry: expiry,
      );
      await _ref.read(shopProvider.notifier).saveShop(updatedShop);
    }
  }
}

class SubscriptionState {
  final bool isActive;
  final DateTime? expiryDate;
  final String planName;

  SubscriptionState({
    required this.isActive,
    this.expiryDate,
    this.planName = 'Basic Plan',
  });

  factory SubscriptionState.initial() => SubscriptionState(
        isActive: true,
        planName: 'Free Trial',
      );

  factory SubscriptionState.expired() => SubscriptionState(isActive: false);
}
