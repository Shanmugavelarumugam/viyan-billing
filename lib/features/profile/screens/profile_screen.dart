import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../subscription/services/subscription_service.dart';
import '../../billing/services/whatsapp_service.dart';
import '../../../data/models/shop_model.dart';
import '../../billing/providers/cart_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final shop = shopState.shop;
    final loc = ref.watch(localizationProvider);
    final subscription = ref.watch(subscriptionProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (loc == null || !shopState.isLoaded || shop == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: 0.05),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative circles in background
              ..._buildBackgroundCircles(primaryColor),

              // Main content
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            // Header Section
                            _buildHeaderSection(shop, loc, primaryColor),
                            const SizedBox(height: 24),

                            // Stats Section
                            _buildStatsSection(
                              shop,
                              subscription,
                              loc,
                              primaryColor,
                            ),
                            const SizedBox(height: 24),

                            // Menu Sections
                            _buildMenuSection(
                              title: loc.translate('subscription'),
                              children: [
                                _buildSubscriptionTile(
                                  subscription,
                                  loc,
                                  primaryColor,
                                ),
                              ],
                            ),

                            _buildMenuSection(
                              title: loc.translate('preferences'),
                              children: [
                                _buildLanguageTile(
                                  ref,
                                  shop,
                                  loc,
                                  primaryColor,
                                ),
                              ],
                            ),

                            _buildMenuSection(
                              title: loc.translate('payment_settings'),
                              children: [
                                _buildPaymentTile(shop, loc, primaryColor),
                                _buildPaymentMethodTile(loc, primaryColor),
                              ],
                            ),

                            _buildMenuSection(
                              title: loc.translate('business_settings'),
                              children: [
                                _buildTokenTile(shop, loc, primaryColor),
                              ],
                            ),

                            _buildMenuSection(
                              title: loc.translate('support'),
                              children: [
                                _buildSupportTile(loc, primaryColor),
                                _buildComplianceTile(loc, primaryColor),
                                _buildAboutTile(loc, primaryColor),
                              ],
                            ),

                            // Logout Button
                            _buildLogoutButton(ref, loc, primaryColor),
                            SizedBox(
                              height:
                                  100 + MediaQuery.paddingOf(context).bottom,
                            ), // Extra space for bottom nav
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundCircles(Color primaryColor) {
    return [
      Positioned(
        top: -80,
        right: -50,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -60,
        left: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [primaryColor.withValues(alpha: 0.1), Colors.transparent],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeaderSection(
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Decorative background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.85),
                      primaryColor.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Decorative circles inside card
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: 30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage:
                          (shop.profilePhotoPath != null &&
                              (shop.profilePhotoPath!.startsWith('http') ||
                                  File(shop.profilePhotoPath!).existsSync()))
                          ? (shop.profilePhotoPath!.startsWith('http')
                                    ? NetworkImage(shop.profilePhotoPath!)
                                    : FileImage(File(shop.profilePhotoPath!)))
                                as ImageProvider
                          : null,
                      child:
                          (shop.profilePhotoPath == null ||
                              (!shop.profilePhotoPath!.startsWith('http') &&
                                  !File(shop.profilePhotoPath!).existsSync()))
                          ? Text(
                              shop.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.alternate_email_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shop.email ?? loc.translate('no_email'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                shop.ownerName ?? loc.translate('owner'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                shop.shopType ?? loc.translate('tea_shop'),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Edit Button
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    surfaceTintColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _showEditProfileDialog(context, ref, shop),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    ShopModel shop,
  ) {
    context.push('/profile/edit');
  }

  Widget _buildStatsSection(
    ShopModel shop,
    SubscriptionState subscription,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    final daysLeft = subscription.expiryDate != null
        ? subscription.expiryDate!.difference(DateTime.now()).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  loc.translate('plan'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subscription.planName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey[100]),
          Expanded(
            child: Column(
              children: [
                Text(
                  loc.translate('days_left').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$daysLeft',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: daysLeft < 5 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey[100]),
          Expanded(
            child: Column(
              children: [
                Text(
                  'TYPE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  shop.shopType ?? loc.translate('items'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required dynamic icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon is IconData
                      ? Icon(icon, color: color, size: 20)
                      : FaIcon(icon as FaIconData, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 64, endIndent: 16, thickness: 0.5),
      ],
    );
  }

  Widget _buildSubscriptionTile(
    SubscriptionState subscription,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    return _buildMenuItem(
      icon: Icons.auto_awesome_rounded,
      color: Colors.purple,
      title: subscription.planName,
      subtitle: loc.translate('subscription_renewal'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          loc.translate('active_status'),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
      ),
      onTap: () => context.push('/profile/renewal'),
      showDivider: false,
    );
  }

  Widget _buildLanguageTile(
    WidgetRef ref,
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    final isTamil = shop.language == 'ta';
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              loc.translate('language'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildLanguageToggle(
                  'EN',
                  !isTamil,
                  () => ref.read(shopProvider.notifier).updateLanguage('en'),
                  primaryColor,
                ),
                _buildLanguageToggle(
                  'தமிழ்',
                  isTamil,
                  () => ref.read(shopProvider.notifier).updateLanguage('ta'),
                  primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    return _buildMenuItem(
      icon: Icons.qr_code_scanner_rounded,
      color: Colors.blue,
      title: loc.translate('upi_id'),
      subtitle: shop.upiId ?? loc.translate('not_linked'),
      onTap: () => _showUpiPasswordDialog(context, ref, shop, loc, primaryColor),
    );
  }

  Widget _buildPaymentMethodTile(AppLocalizations loc, Color primaryColor) {
    return _buildMenuItem(
      icon: Icons.payments_rounded,
      color: Colors.green,
      title: loc.translate('payment_methods'),
      subtitle: loc.translate('cash_upi'),
      trailing: Switch(
        value: true,
        onChanged: (v) {},
        activeThumbColor: Colors.green,
      ),
      showDivider: false,
    );
  }

  Widget _buildTokenTile(
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    return _buildMenuItem(
      icon: Icons.confirmation_number_rounded,
      color: Colors.orange,
      title: loc.translate('token_numbering'),
      subtitle: loc.translate(
        'start_from',
        args: {'number': shop.tokenStartNumber.toString()},
      ),
      onTap: () => _showTokenNumberDialog(context, ref, shop, loc, primaryColor),
    );
  }

  Widget _buildBackupTile(AppLocalizations loc, Color primaryColor) {
    return _buildMenuItem(
      icon: Icons.cloud_sync_rounded,
      color: Colors.teal,
      title: loc.translate('cloud_backup'),
      subtitle: loc.translate('backup_active'),
      trailing: const Icon(
        Icons.check_circle_rounded,
        color: Colors.teal,
        size: 20,
      ),
      onTap: () {
        final subscription = ref.read(subscriptionProvider);
        if (!subscription.isActive) {
          showSubscriptionExpiredDialog(context);
          return;
        }
      },
      showDivider: false,
    );
  }

  Widget _buildSupportTile(AppLocalizations loc, Color primaryColor) {
    return _buildMenuItem(
      icon: FontAwesomeIcons.whatsapp,
      color: Colors.green,
      title: loc.translate('whatsapp_support'),
      subtitle: loc.translate('immediate_assistance'),
      onTap: () => WhatsappService.launchSupport(),
    );
  }

  Widget _buildComplianceTile(AppLocalizations loc, Color primaryColor) {
    return _buildMenuItem(
      icon: Icons.gavel_rounded,
      color: Colors.blueGrey,
      title: loc.translate('compliance_legal'),
      subtitle: loc.translate('tos_privacy'),
      onTap: () => _showComplianceDialog(context),
    );
  }

  Widget _buildAboutTile(AppLocalizations loc, Color primaryColor) {
    return _buildMenuItem(
      icon: Icons.info_rounded,
      color: Colors.grey,
      title: loc.translate('about_app'),
      subtitle: loc.translate('version', args: {'version': '1.0.0+1'}),
      onTap: () => _showAboutDialog(context),
      showDivider: false,
    );
  }

  Widget _buildLogoutButton(
    WidgetRef ref,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: () => _showLogoutDialog(context, ref, loc, primaryColor),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  loc.translate('logout'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.red,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with gradient background
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withValues(alpha: 0.15),
                      Colors.red.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.translate('logout'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.translate('logout_confirm'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              loc.translate('cancel'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Material(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(18),
                      elevation: 4,
                      shadowColor: Colors.red.withValues(alpha: 0.3),
                      child: InkWell(
                        onTap: () async {
                          final router = GoRouter.of(context);
                          ref.read(authProvider.notifier).logout();
                          await ref.read(shopProvider.notifier).clearShop();
                          if (context.mounted) {
                            Navigator.pop(context);
                            router.go('/login');
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              loc.translate('logout').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.info_rounded, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'About Viyan Billing',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: 1.0.0+1',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Viyan Billing is a premium POS and inventory management solution designed for modern business owners.',
            ),
            SizedBox(height: 12),
            Text('© 2026 Viyan Technologies. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showComplianceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Compliance & Legal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegalSection(
                'Terms of Service',
                'By using Viyan Billing, you agree to our terms of processing business data securely and maintaining account confidentiality.',
              ),
              const SizedBox(height: 16),
              _buildLegalSection(
                'Privacy Policy',
                'Your data is encrypted and synced only with your authorized cloud storage. We never share your business transactions with third parties.',
              ),
              const SizedBox(height: 16),
              _buildLegalSection(
                'Data Ownership',
                'All inventory and sales data belongs entirely to the shop owner. You can export or delete your data at any time.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'UNDERSTOOD',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpiPasswordDialog(
    BuildContext context,
    WidgetRef ref,
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    final passwordController = TextEditingController();
    bool obscureText = true;
    bool isVerifying = false;
    String? errorText;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  backgroundColor: Colors.white,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.lock_rounded, color: Colors.white, size: 38),
                              SizedBox(height: 10),
                              Text(
                                'Verify Identity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enter your account password to edit UPI ID',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
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
                                'PASSWORD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[500],
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: passwordController,
                                obscureText: obscureText,
                                autofocus: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  hintText: 'Enter your password',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  errorText: errorText,
                                  prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    onPressed: () => setDialogState(() => obscureText = !obscureText),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey[200]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      child: Text(
                                        'CANCEL',
                                        style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isVerifying
                                          ? null
                                          : () async {
                                              final password = passwordController.text;
                                              if (password.isEmpty) {
                                                setDialogState(() => errorText = 'Password cannot be empty');
                                                return;
                                              }
                                              setDialogState(() {
                                                isVerifying = true;
                                                errorText = null;
                                              });
                                              try {
                                                final authState = ref.read(authProvider);
                                                final email = authState.email ?? '';
                                                await ref.read(authProvider.notifier).login(email, password);
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                  Future.delayed(const Duration(milliseconds: 150), () {
                                                    if (context.mounted) {
                                                      _showUpiEditDialog(context, ref, shop, loc, primaryColor);
                                                    }
                                                  });
                                                }
                                              } catch (e) {
                                                setDialogState(() {
                                                  isVerifying = false;
                                                  errorText = 'Incorrect password. Please try again.';
                                                });
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: isVerifying
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Text('VERIFY', style: TextStyle(fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showUpiEditDialog(
    BuildContext context,
    WidgetRef ref,
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    final upiController = TextEditingController(text: shop.upiId ?? '');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 38),
                          SizedBox(height: 10),
                          Text(
                            'Edit UPI ID',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
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
                            'UPI ID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: upiController,
                            autofocus: true,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              hintText: 'e.g. yourname@upi',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                              prefixIcon: const Icon(Icons.qr_code_rounded, color: Colors.blue),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final newUpiId = upiController.text.trim();
                                    final updatedShop = shop.copyWith(upiId: newUpiId.isEmpty ? null : newUpiId);
                                    Navigator.pop(context);
                                    ref.read(shopProvider.notifier).saveShop(updatedShop);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 10),
                                            Text('UPI ID updated successfully'),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTokenNumberDialog(
    BuildContext context,
    WidgetRef ref,
    ShopModel shop,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    final controller =
        TextEditingController(text: shop.tokenStartNumber.toString());
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 42),
                          SizedBox(height: 12),
                          Text(
                            'Token Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
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
                            'DAILY START NUMBER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[50],
                              prefixIcon: Icon(Icons.numbers_rounded, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Every morning, your token count will automatically reset to this number.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                          ),
                          const SizedBox(height: 32),
                          
                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final newStart = int.tryParse(controller.text) ?? 1;
                                    final updatedShop = shop.copyWith(tokenStartNumber: newStart);
                                    
                                    // Close immediately and save in background
                                    Navigator.pop(context);
                                    ref.read(shopProvider.notifier).saveShop(updatedShop);

                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      if (context.mounted) {
                                        _showResetCurrentTokenDialog(
                                          context,
                                          ref,
                                          newStart,
                                          loc,
                                          primaryColor,
                                        );
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'SAVE',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showResetCurrentTokenDialog(
    BuildContext context,
    WidgetRef ref,
    int newStart,
    AppLocalizations loc,
    Color primaryColor,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.restart_alt_rounded, color: Colors.orange, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Reset Now?',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Do you want to reset your current token to #$newStart immediately?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'NO, KEEP',
                                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    ref.read(tokenProvider.notifier).reset(newStart);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Token reset to #$newStart'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.orange,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'YES, RESET',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegalSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
