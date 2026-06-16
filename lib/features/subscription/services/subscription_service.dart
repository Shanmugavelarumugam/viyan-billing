import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/services/time_sync_service.dart';
import '../../../core/services/notification_service.dart';

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});

final readOnlyModeSelectedProvider = StateProvider<bool>((ref) => false);

void showSubscriptionExpiredDialog(BuildContext context) {
  final theme = Theme.of(context);
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Consumer(
            builder: (context, ref, child) {
              final l10n = ref.watch(localizationProvider);
              String translate(String key) => l10n?.translate(key) ?? key;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          translate('feature_locked'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('billing_disabled_readonly'),
                          style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureItem(context, translate('feature_create_invoices')),
                        const SizedBox(height: 8),
                        _buildFeatureItem(context, translate('feature_manage_stock')),
                        const SizedBox(height: 8),
                        _buildFeatureItem(context, translate('feature_print_share')),
                        const SizedBox(height: 8),
                        _buildFeatureItem(context, translate('feature_adv_reports')),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                child: Text(translate('close_caps'), style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  GoRouter.of(context).push('/profile/renewal');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(translate('renew_now'), style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

Widget _buildFeatureItem(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Row(
    children: [
      Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;
  DateTime? _lastScheduledExpiry;

  SubscriptionNotifier(this._ref) : super(SubscriptionState.initial()) {
    _ref.listen<ShopState>(shopProvider, (previous, next) {
      _updateStatus(next);
    });
    _ref.listen<TimeSyncState>(timeSyncProvider, (previous, next) {
      _updateStatus(_ref.read(shopProvider));
    });
    _updateStatus(_ref.read(shopProvider));
  }

  void _updateStatus(ShopState shopState) {
    final shop = shopState.shop;
    if (shop == null) {
      // Default to active for setup, or if not loaded yet
      state = SubscriptionState(isActive: true, planName: 'Free Trial');
      return;
    }

    final syncState = _ref.read(timeSyncProvider);
    
    // Check offline sync validity first!
    if (!syncState.isOfflineSyncValid || syncState.isBlacklisted) {
      state = SubscriptionState(
        isActive: false,
        expiryDate: shop.subscriptionExpiry,
        planName: shop.subscriptionPlan ?? 'Expired',
        isOfflineBlock: true,
        isBlacklisted: syncState.isBlacklisted,
      );
      return;
    }

    final expiry = shop.subscriptionExpiry;
    final offset = syncState.offset;
    final now = DateTime.now().add(Duration(milliseconds: offset));
    const graceDays = 2;
    
    debugPrint('========== SUB CHECK ==========');
    debugPrint('Plan: ${shop.subscriptionPlan}');
    debugPrint('Expiry: $expiry');
    debugPrint('Now: $now');
    debugPrint('Is Active (Grace excluded): ${expiry?.isAfter(now)}');
    debugPrint('Offline Block: ${!syncState.isOfflineSyncValid}');
    debugPrint('Blacklisted: ${syncState.isBlacklisted}');
    debugPrint('==============================');
    
    if (expiry != null) {
      if (expiry.isAfter(now)) {
        final remaining = expiry.difference(now);
        final daysRemaining = (remaining.inMinutes / (24 * 60)).ceil();
        final isNearExpiry = daysRemaining <= 3;

        // Schedule reminders only if expiry date changed
        if (_lastScheduledExpiry == null ||
            _lastScheduledExpiry!.difference(expiry).inMinutes.abs() > 1) {
          _lastScheduledExpiry = expiry;
          final expiry3DaysBefore = expiry.subtract(const Duration(days: 3));
          final expiry1DayBefore = expiry.subtract(const Duration(days: 1));
          NotificationService.cancelAll().then((_) {
            NotificationService.scheduleNotification(
              id: 1,
              title: "Free trial ending soon",
              body: "Your free trial ends in 3 days. Renew now to continue billing.",
              scheduledDate: expiry3DaysBefore,
            );
            NotificationService.scheduleNotification(
              id: 2,
              title: "Free trial ending tomorrow",
              body: "Your free trial ends tomorrow. Renew now to avoid read-only mode.",
              scheduledDate: expiry1DayBefore,
            );
          });
        }

        state = SubscriptionState(
          isActive: true,
          expiryDate: expiry,
          planName: shop.subscriptionPlan ?? 'Free Trial',
          isGraceActive: false,
          graceDaysRemaining: 0,
          isNearExpiry: isNearExpiry,
          daysRemaining: daysRemaining,
        );
      } else {
        final graceExpiry = expiry.add(const Duration(days: graceDays));
        if (now.isBefore(graceExpiry)) {
          final remaining = graceExpiry.difference(now);
          final daysRemaining = (remaining.inMinutes / (24 * 60)).ceil();
          state = SubscriptionState(
            isActive: true,
            expiryDate: expiry,
            planName: shop.subscriptionPlan ?? 'Free Trial',
            isGraceActive: true,
            graceDaysRemaining: daysRemaining > 0 ? daysRemaining : 1,
            isNearExpiry: false,
            daysRemaining: 0,
          );
        } else {
          state = SubscriptionState(
            isActive: false,
            expiryDate: expiry,
            planName: shop.subscriptionPlan ?? 'Expired',
            isGraceActive: false,
            graceDaysRemaining: 0,
            isNearExpiry: false,
            daysRemaining: 0,
          );
        }
      }
    } else {
      final plan = shop.subscriptionPlan ?? 'Free Trial';
      if (plan == 'Free Trial') {
        debugPrint('⚠️ Missing expiry for free trial. Defaulting to active (15 days remaining).');
        state = SubscriptionState(
          isActive: true,
          expiryDate: null,
          planName: 'Free Trial',
          isGraceActive: false,
          graceDaysRemaining: 0,
          isNearExpiry: false,
          daysRemaining: 15,
        );
      } else {
        state = SubscriptionState(
          isActive: false,
          expiryDate: null,
          planName: 'Expired',
          isGraceActive: false,
          graceDaysRemaining: 0,
          isNearExpiry: false,
          daysRemaining: 0,
        );
      }
    }
  }

  void checkStatus() {
    _updateStatus(_ref.read(shopProvider));
  }

  Future<void> renewPlan(String planName, int days) async {
    final syncState = _ref.read(timeSyncProvider);
    final offset = syncState.offset;
    final now = DateTime.now().add(Duration(milliseconds: offset));
    final expiry = now.add(Duration(days: days));
    state = SubscriptionState(
      isActive: true,
      expiryDate: expiry,
      planName: planName,
      isGraceActive: false,
      graceDaysRemaining: 0,
      isNearExpiry: false,
      daysRemaining: 0,
      isOfflineBlock: false,
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
  final bool isGraceActive;
  final int graceDaysRemaining;
  final bool isNearExpiry;
  final int daysRemaining;
  final bool isOfflineBlock;
  final bool isBlacklisted;

  SubscriptionState({
    required this.isActive,
    this.expiryDate,
    this.planName = 'Basic Plan',
    this.isGraceActive = false,
    this.graceDaysRemaining = 0,
    this.isNearExpiry = false,
    this.daysRemaining = 0,
    this.isOfflineBlock = false,
    this.isBlacklisted = false,
  });

  factory SubscriptionState.initial() => SubscriptionState(
        isActive: true,
        planName: 'Free Trial',
        isGraceActive: false,
        graceDaysRemaining: 0,
        isNearExpiry: false,
        daysRemaining: 0,
        isOfflineBlock: false,
        isBlacklisted: false,
      );

  factory SubscriptionState.expired() => SubscriptionState(
        isActive: false,
        isGraceActive: false,
        graceDaysRemaining: 0,
        isNearExpiry: false,
        daysRemaining: 0,
        isOfflineBlock: false,
        isBlacklisted: false,
      );
}

