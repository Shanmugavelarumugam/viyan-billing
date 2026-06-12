import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/localization_provider.dart';
import '../localization/app_localizations.dart';

// Providers & Models
import '../../features/shop_setup/providers/shop_provider.dart';

// Screens
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/shop_setup/screens/shop_setup_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/items/screens/items_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/subscription/screens/plan_renewal_screen.dart';
import '../../features/subscription/screens/plan_expiry_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/billing/providers/cart_provider.dart';
import '../../features/billing/screens/checkout_screen.dart';
import '../../features/subscription/services/subscription_service.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

// We use a Listenable to notify the router of state changes without recreating the router instance
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    // Use the provider's state as the source of truth
    refreshListenable: _RouterRefreshStream(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final shopState = ref.read(shopProvider);

      final isSplash = state.matchedLocation == '/';
      final isLogin = state.matchedLocation == '/login';
      final isSignup = state.matchedLocation == '/signup';
      final isShopSetup = state.matchedLocation == '/shop-setup';

      // If NOT yet loaded, stay on splash or current screen
      if (auth.isAuthenticated && !shopState.isLoaded) {
        return null;
      }

      final shop = shopState.shop;
      
      // If we have auth AND shop profile, skip onboarding and go to billing
      if (auth.isAuthenticated && shop != null) {
        if (isSplash || isLogin || isSignup || isShopSetup) {
          return '/billing';
        }
      }

      // If authenticated but NO shop profile, force shop-setup
      if (auth.isAuthenticated && shop == null) {
        if (!isShopSetup) return '/shop-setup';
      }

      // If NOT authenticated, and trying to access protected routes, go to login
      if (!auth.isAuthenticated) {
        if (!isSplash && !isLogin && !isSignup) return '/login';
      }

      // If authenticated and subscription is EXPIRED, force expiry screen
      // (Unless they are already on the renewal screen to fix it)
      final subscription = ref.read(subscriptionProvider);
      if (auth.isAuthenticated && !subscription.isActive) {
        final isRenewal = state.matchedLocation == '/profile/renewal';
        final isExpiry = state.matchedLocation == '/profile/expiry';
        if (!isRenewal && !isExpiry) {
          return '/profile/expiry';
        }
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/shop-setup',
        builder: (context, state) => const ShopSetupScreen(),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/billing',
                builder: (context, state) => const BillingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/items',
                builder: (context, state) => const ItemsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(),
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'renewal',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const PlanRenewalScreen(),
                  ),
                  GoRoute(
                    path: 'expiry',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const PlanExpiryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper class to bridge Riverpod states to GoRouter's refreshListenable
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Ref ref) {
    _subscription = ref.listen(authProvider, (_, _) => notifyListeners());
    _shopSubscription = ref.listen(shopProvider, (_, _) => notifyListeners());
    _subStatusSubscription = ref.listen(subscriptionProvider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription _subscription;
  late final ProviderSubscription _shopSubscription;
  late final ProviderSubscription _subStatusSubscription;

  @override
  void dispose() {
    _subscription.close();
    _shopSubscription.close();
    _subStatusSubscription.close();
    super.dispose();
  }
}

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    final theme = Theme.of(context);
    final cartState = ref.watch(cartProvider);
    
    // Hide nav bar if on billing tab AND cart has items
    final bool showNavBar = navigationShell.currentIndex != 0 || 
                           cartState.selectedBill.items.isEmpty;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If NOT on the first tab (Billing), go to the first tab
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }

        // 2. If already on Billing, show a beautiful exit confirmation
        final shouldExit = await _showExitConfirmation(context, theme, l10n);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Content Area
            Positioned.fill(child: navigationShell),
            
            // Floating Nav Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              left: 20,
              right: 20,
              bottom: showNavBar 
                  ? (16 + MediaQuery.paddingOf(context).bottom) 
                  : -100,
              child: _buildFloatingNavBar(context, theme, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmation(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? l10n,
  ) {
    return showGeneralDialog<bool>(
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      child: const Column(
                        children: [
                          Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 42),
                          SizedBox(height: 12),
                          Text(
                            'Quit Viyan Billing?',
                            style: TextStyle(
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
                        children: [
                          Text(
                            'Are you sure you want to close the app? Any unsaved changes in billing might be lost.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                  child: Text('STAY', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text('QUIT', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _buildFloatingNavBar(BuildContext context, ThemeData theme, WidgetRef ref, l10n) {
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark 
        ? theme.colorScheme.surfaceContainerHigh 
        : Colors.white;
    final shadowColor = isDark ? Colors.black45 : Colors.black12;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildNavItem(
              index: 0,
              icon: Icons.receipt_long_rounded,
              label: l10n?.translate('billing') ?? 'Billing',
              theme: theme,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 1,
              icon: Icons.bar_chart_rounded,
              label: l10n?.translate('reports') ?? 'Reports',
              theme: theme,
            ),
          ),
          
          // Central "Add Bill" Action
          Transform.translate(
            offset: const Offset(0, -12),
            child: GestureDetector(
              onTap: () {
                // Quick add bill and switch to home
                ref.read(cartProvider.notifier).addBill();
                navigationShell.goBranch(0);
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _buildNavItem(
              index: 2,
              icon: Icons.inventory_2_rounded,
              label: l10n?.translate('items') ?? 'Items',
              theme: theme,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 3,
              icon: Icons.person_rounded,
              label: l10n?.translate('profile') ?? 'Profile',
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = navigationShell.currentIndex == index;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = Colors.grey[400]!;

    return InkWell(
      onTap: () => navigationShell.goBranch(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
