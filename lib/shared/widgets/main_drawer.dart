import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/localization_provider.dart';
import '../../data/models/shop_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class MainDrawer extends ConsumerWidget {
  final ShopModel? shop;

  const MainDrawer({super.key, this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildCompactHeader(context, primaryColor),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildSectionTitle('ADMINISTRATION'),
                _buildDrawerItem(
                  icon: Icons.print_rounded,
                  label: 'Printer Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/printer-settings');
                  },
                  primaryColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.card_membership_rounded,
                  label: 'Subscription',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile/renewal');
                  },
                  primaryColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.cloud_sync_rounded,
                  label: 'Backup & Sync',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/backup-sync');
                  },
                  primaryColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  },
                  primaryColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  label: 'App Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile/edit');
                  },
                  primaryColor: primaryColor,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                _buildSectionTitle('SUPPORT'),
                _buildDrawerItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/help-support');
                  },
                  primaryColor: primaryColor,
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About App',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/about-app');
                  },
                  primaryColor: primaryColor,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authProvider.notifier).logout();
                  },
                  primaryColor: Colors.redAccent,
                  isDestructive: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Text(
              'Viyan Billing v1.0.0',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, Color primaryColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shop?.name ?? 'Your Shop',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Admin / Cashier',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shop?.name != null ? shop!.name.length > 5 ? shop!.name.substring(0, 5).toUpperCase() : shop!.name.toUpperCase() : 'MAIN',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color primaryColor,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(
          icon,
          color: isDestructive ? primaryColor : Colors.grey[700],
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDestructive ? primaryColor : const Color(0xFF334155),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        hoverColor: isDestructive ? primaryColor.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
      ),
    );
  }
}