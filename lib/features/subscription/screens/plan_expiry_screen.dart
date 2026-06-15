import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/localization_provider.dart';
import '../../billing/services/whatsapp_service.dart';
import '../services/subscription_service.dart';
import '../../../core/services/time_sync_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop_setup/providers/shop_provider.dart';

class PlanExpiryScreen extends ConsumerWidget {
  const PlanExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    final theme = Theme.of(context);
    final subscription = ref.watch(subscriptionProvider);

    if (l10n == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool isBlacklisted = subscription.isBlacklisted;
    final bool isOffline = subscription.isOfflineBlock && !isBlacklisted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                _buildExpiryIcon(theme, isOffline, isBlacklisted),
                const SizedBox(height: 20),
                
                // Badge
                if (isBlacklisted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: const Text(
                      'Tampering Detected • Device Locked',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Text(
                      'Sync Pending • Sync Required',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Text(
                      'Free Trial Completed • 15/15 days used',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                
                Text(
                  isBlacklisted
                      ? l10n.translate('device_blocked')
                      : (isOffline ? l10n.translate('connection_required') : l10n.translate('plan_expired')),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isBlacklisted
                      ? l10n.translate('device_blocked_desc')
                      : (isOffline ? l10n.translate('connection_required_desc') : l10n.translate('plan_expired_desc')),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                if (isBlacklisted)
                  ElevatedButton(
                    onPressed: () => WhatsappService.launchSupport(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded),
                        SizedBox(width: 10),
                        Text(
                          'CONTACT SUPPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isOffline)
                  ElevatedButton(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      await ref.read(timeSyncProvider.notifier).syncTime();
                      if (context.mounted) {
                        Navigator.pop(context); // Dismiss spinner
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.translate('try_sync'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => context.push('/profile/renewal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.translate('renew_now'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                
                if (!isOffline && !isBlacklisted) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ref.read(readOnlyModeSelectedProvider.notifier).state = true;
                      context.go('/billing');
                    },
                    child: Text(
                      'CONTINUE IN READ-ONLY MODE',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can still view invoices, products, and reports.\nNew billing is disabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                
                // WhatsApp Support Section
                if (!isBlacklisted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Need help renewing? ',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => WhatsappService.launchSupport(),
                        child: const Text(
                          'WhatsApp us',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    ref.read(shopProvider.notifier).clearShop();
                  },
                  child: Text(
                    l10n.translate('logout'),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryIcon(ThemeData theme, bool isOffline, bool isBlacklisted) {
    final color = isBlacklisted ? Colors.red : (isOffline ? Colors.blue : Colors.red);
    final icon = isBlacklisted
        ? Icons.gavel_rounded
        : (isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded);
        
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: color[50],
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color[100],
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          icon,
          color: color,
          size: 50,
        ),
      ],
    );
  }
}
