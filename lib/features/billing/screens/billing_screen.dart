import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../providers/cart_provider.dart';
import '../providers/billing_provider.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../../data/models/item_model.dart';
import '../../../data/models/shop_model.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../services/voice_billing_service.dart';
import '../../subscription/services/subscription_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/main_drawer.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  final _phoneController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    debugPrint('📱 Items screen opened');
    try {
      final box = Hive.box<ItemModel>('items_box');
      debugPrint('📦 Hive count: ${box.length}');
    } catch (e) {
      debugPrint('⚠️ Error reading Hive box count: $e');
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Consumer(builder: (context, ref, _) {
        final shop = ref.watch(shopProvider.select((s) => s.shop));
        return MainDrawer(shop: shop);
      }),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryColor.withValues(alpha: 0.03),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ..._buildBackgroundCircles(),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Consumer(builder: (context, ref, _) {
                            final subState = ref.watch(subscriptionProvider);
                            final l10n = ref.watch(localizationProvider);
                            if (l10n == null) return const SizedBox();
                            if (subState.isGraceActive) {
                              return _buildGracePeriodBanner(context, subState.graceDaysRemaining, l10n);
                            } else if (subState.isNearExpiry) {
                              return _buildTrialReminderBanner(context, subState.daysRemaining, l10n);
                            }
                            return const SizedBox();
                          }),
                          Consumer(builder: (context, ref, _) {
                            final shop = ref.watch(shopProvider.select((s) => s.shop));
                            final bill = ref.watch(cartProvider.select((s) => s.selectedBill));
                            final l10n = ref.watch(localizationProvider);
                            if (l10n == null) return const SizedBox();
                            return _buildHeader(shop, l10n, bill);
                          }),
                          Consumer(builder: (context, ref, _) {
                            final state = ref.watch(cartProvider);
                            final l10n = ref.watch(localizationProvider);
                            if (l10n == null) return const SizedBox();
                            return _buildBillSwitcher(state, ref, l10n);
                          }),
                          Consumer(builder: (context, ref, _) {
                            final categories = ref.watch(itemCategoriesProvider);
                            final l10n = ref.watch(localizationProvider);
                            if (l10n == null) return const SizedBox();
                            return _buildCategorySection(categories, l10n);
                          }),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      20, 16, 20,
                      120 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: Consumer(builder: (context, ref, _) {
                      final filteredItems = ref.watch(filteredItemsProvider(_selectedCategory));
                      final bill = ref.watch(cartProvider.select((s) => s.selectedBill));
                      return _buildItemsGrid(filteredItems, bill, ref, isTablet);
                    }),
                  ),
                ],
              ),
              // Floating cart — independent consumer so it rebuilds without touching the grid
              Consumer(builder: (context, ref, _) {
                final bill = ref.watch(cartProvider.select((s) => s.selectedBill));
                if (bill.items.isEmpty) return const SizedBox();
                final shop = ref.watch(shopProvider.select((s) => s.shop));
                final l10n = ref.watch(localizationProvider);
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildFloatingCart(ref, bill, shop, l10n),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundCircles() {
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
                _primaryColor.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 100,
        left: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _primaryColor.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeader(
    ShopModel? shop,
    AppLocalizations? l10n,
    CartBill selectedBill,
  ) {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: _primaryColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.notes_rounded,
                    color: _primaryColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop?.name ?? 'Your Shop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showBarcodeScannerSheet(context, ref, l10n),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _primaryColor,
                    size: 18,
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillSwitcher(
    ActiveBillsState state,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: state.bills.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: () {
                final subscription = ref.read(subscriptionProvider);
                if (!subscription.isActive) {
                  showSubscriptionExpiredDialog(context);
                  return;
                }
                ref.read(cartProvider.notifier).addBill();
              },
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_rounded, color: _primaryColor, size: 24),
              ),
            );
          }
          final bill = state.bills[index - 1];
          final isSelected = state.selectedBillId == bill.id;
          return GestureDetector(
            onTap: () => ref.read(cartProvider.notifier).selectBill(bill.id),
            onLongPress: () => _showCancelDialog(context, ref, bill.id, l10n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[200]!,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _primaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  children: [
                    if (bill.isHold)
                      Icon(
                        Icons.pause_circle_filled,
                        size: 14,
                        color: isSelected ? Colors.white70 : Colors.grey,
                      ),
                    if (bill.isHold) const SizedBox(width: 4),
                    Text(
                      bill.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(List<String> categories, l10n) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.grey[200]!,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsGrid(
    List<ItemModel> items,
    CartBill selectedBill,
    WidgetRef ref,
    bool isTablet,
  ) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildEmptyState(),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        int crossAxisCount = 2;
        if (width > 600) crossAxisCount = 3;
        if (width > 900) crossAxisCount = 4;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];
            final cartItem = selectedBill.items.firstWhere(
              (i) => i.item.id == item.id,
              orElse: () => CartItemModel(item: item, quantity: 0),
            );
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildItemCard(item, cartItem, ref),
            );
          }, childCount: items.length),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 64,
              color: _primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No items in this category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different category',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ItemModel item, CartItemModel cartItem, WidgetRef ref) {
    final hasQty = cartItem.quantity > 0;

    return GestureDetector(
      onTap: () {
        final subscription = ref.read(subscriptionProvider);
        if (!subscription.isActive) {
          showSubscriptionExpiredDialog(context);
          return;
        }
        HapticFeedback.lightImpact();
        final success = ref.read(cartProvider.notifier).addItem(item);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient stock for ${item.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onLongPress: () {
        final subscription = ref.read(subscriptionProvider);
        if (!subscription.isActive) {
          showSubscriptionExpiredDialog(context);
          return;
        }
        HapticFeedback.mediumImpact();
        ref.read(cartProvider.notifier).removeItem(item);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: hasQty
                  ? _primaryColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: hasQty ? _primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 12,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildItemImage(item, size: 40)),
                    if (hasQty)
                      Positioned.fill(
                        child: Container(
                          color: _primaryColor.withValues(alpha: 0.05),
                        ),
                      ),
                    if (hasQty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () {
                            final subscription = ref.read(subscriptionProvider);
                            if (!subscription.isActive) {
                              showSubscriptionExpiredDialog(context);
                              return;
                            }
                            HapticFeedback.mediumImpact();
                            ref.read(cartProvider.notifier).removeItem(item);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              color: _primaryColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (hasQty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${cartItem.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCart(WidgetRef ref, CartBill bill, shop, l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bill.items.length} ${bill.items.length == 1 ? 'ITEM' : 'ITEMS'}',
                        maxLines: 1,
                        style: TextStyle(
                          color: _primaryColor.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${bill.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Quick Actions
                _buildCircularAction(
                  icon: Icons.pause_rounded,
                  color: Colors.orange,
                  onTap: () => ref.read(cartProvider.notifier).holdBill(),
                ),
                const SizedBox(width: 8),
                // Main Action
                GestureDetector(
                  onTap: () => context.push('/checkout'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'CHECKOUT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
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

  void _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    String billId,
    l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Cancel Bill',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to cancel this bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'NO',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).removeBill(billId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'YES',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceBillingSheet(BuildContext context, WidgetRef ref, l10n) {
    final voiceService = ref.read(voiceBillingServiceProvider);
    final availableItems = ref.read(itemsProvider);

    String recognizedText = "";
    bool isListening = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'VOICE BILLING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    final subscription = ref.read(subscriptionProvider);
                    if (!subscription.isActive) {
                      showSubscriptionExpiredDialog(context);
                      return;
                    }
                    if (isListening) {
                      await voiceService.stopListening();
                      setState(() => isListening = false);
                    } else {
                      final initialized = await voiceService.initialize();
                      if (initialized) {
                        setState(() {
                          isListening = true;
                          recognizedText = "";
                        });
                        await voiceService.startListening(
                          localeId: 'en',
                          onResult: (text) {
                            setState(() => recognizedText = text);
                          },
                        );
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isListening
                          ? Colors.red.withValues(alpha: 0.1)
                          : _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                    ),
                    child: Icon(
                      isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 56,
                      color: isListening ? Colors.red : _primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isListening ? 'Listening...' : 'Tap to Speak',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isListening ? Colors.red : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    recognizedText.isEmpty
                        ? 'Example: "2 tea 1 dosa"'
                        : recognizedText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: recognizedText.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: recognizedText.isEmpty
                          ? Colors.grey[400]
                          : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: recognizedText.isEmpty
                      ? null
                      : () {
                          final results = voiceService.parseSpeech(
                            recognizedText,
                            availableItems,
                          );
                          if (results.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not recognize items'),
                              ),
                            );
                          } else {
                            int addedCount = 0;
                            for (final res in results) {
                              for (int i = 0; i < res.quantity; i++) {
                                final success = ref
                                    .read(cartProvider.notifier)
                                    .addItem(res.item);
                                if (success) {
                                  addedCount++;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Insufficient stock for ${res.item.name}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                            Navigator.pop(context);
                            if (addedCount > 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✅ Added $addedCount items!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'ADD TO CART',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildItemImage(ItemModel item, {double size = 32}) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return Center(
        child: Icon(Icons.restaurant_rounded, color: _primaryColor, size: size),
      );
    }

    if (!item.imageUrl!.startsWith('http')) {
      final file = File(item.imageUrl!);
      if (!file.existsSync()) {
        return Center(
          child: Icon(
            Icons.restaurant_rounded,
            color: _primaryColor,
            size: size,
          ),
        );
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.restaurant_rounded, color: _primaryColor, size: size),
      );
    }

    return CachedNetworkImage(
      imageUrl: item.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _primaryColor.withValues(alpha: 0.3),
        ),
      ),
      errorWidget: (context, url, error) =>
          Icon(Icons.restaurant_rounded, color: _primaryColor, size: size),
    );
  }

  // --- BARCODE SCANNING & QUICK ADD CHEKOUT IMPLEMENTATION ---

  void _showBarcodeScannerSheet(BuildContext context, WidgetRef ref, l10n) {
    bool isCameraMode = true;
    final barcodeManualController = TextEditingController();
    final availableItems = ref.read(itemsProvider);
    final itemsWithBarcodes = availableItems.where((i) => i.barcode != null && i.barcode!.isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.qr_code_scanner_rounded, color: _primaryColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'BARCODE SCANNER',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Premium Mode Selector Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => isCameraMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isCameraMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isCameraMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      size: 16,
                                      color: isCameraMode ? _primaryColor : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Live Camera',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isCameraMode ? _primaryColor : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => isCameraMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isCameraMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isCameraMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.devices_rounded,
                                      size: 16,
                                      color: !isCameraMode ? _primaryColor : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Simulator / Test',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: !isCameraMode ? _primaryColor : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: isCameraMode
                        ? Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 24),
                                height: 260,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    children: [
                                      MobileScanner(
                                        fit: BoxFit.cover,
                                        onDetect: (capture) {
                                          final List<Barcode> barcodes = capture.barcodes;
                                          if (barcodes.isNotEmpty) {
                                            final String? code = barcodes.first.rawValue;
                                            if (code != null && code.isNotEmpty) {
                                              HapticFeedback.heavyImpact();
                                              Navigator.pop(context);
                                              _onBarcodeDetected(context, ref, code, l10n);
                                            }
                                          }
                                        },
                                      ),
                                      // Premium scanning frame target overlay
                                      Center(
                                        child: Container(
                                          width: 200,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: _primaryColor, width: 3),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Stack(
                                            children: [
                                              // Decorative corner highlights
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                right: 10,
                                                bottom: 10,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.white.withValues(alpha: 0.3),
                                                      width: 1,
                                                    ),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Align barcode inside frame',
                                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Trouble using camera?',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                              TextButton(
                                onPressed: () => setSheetState(() => isCameraMode = false),
                                child: Text('Switch to Simulator / Manual Input', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // manual textfield input
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: TextField(
                                    controller: barcodeManualController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Barcode number (e.g. 8901725181223)',
                                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                      prefixIcon: Icon(Icons.qr_code_rounded, color: Colors.grey[400]),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.arrow_forward_rounded, color: _primaryColor),
                                        onPressed: () {
                                          final val = barcodeManualController.text.trim();
                                          if (val.isNotEmpty) {
                                            Navigator.pop(context);
                                            _onBarcodeDetected(context, ref, val, l10n);
                                          }
                                        },
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                    onSubmitted: (val) {
                                      final code = val.trim();
                                      if (code.isNotEmpty) {
                                        Navigator.pop(context);
                                        _onBarcodeDetected(context, ref, code, l10n);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'DEMO SIMULATION SHORTCUTS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Instant Hide & Seek demo button
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange.shade50, Colors.orange.shade100.withValues(alpha: 0.3)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: const Icon(Icons.cookie_rounded, color: Colors.white),
                                    ),
                                    title: const Text(
                                      'Hide & Seek Biscuits',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    subtitle: const Text(
                                      'Simulate scanning unregistered biscuits\nBarcode: 8901725181223',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'SCAN',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _onBarcodeDetected(context, ref, '8901725181223', l10n);
                                    },
                                  ),
                                ),
                                // Existing catalog items shortcuts
                                if (itemsWithBarcodes.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'SCAN FROM ACTIVE CATALOG',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...itemsWithBarcodes.map((item) => Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey[200]!),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Barcode: ${item.barcode} • ₹${item.price.toStringAsFixed(0)}'),
                                          trailing: Icon(Icons.qr_code_rounded, color: _primaryColor),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _onBarcodeDetected(context, ref, item.barcode!, l10n);
                                          },
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onBarcodeDetected(BuildContext context, WidgetRef ref, String barcode, l10n) {
    final subscription = ref.read(subscriptionProvider);
    if (!subscription.isActive) {
      showSubscriptionExpiredDialog(context);
      return;
    }

    final availableItems = ref.read(itemsProvider);
    
    // Check if the barcode matches any existing item
    final matchedItem = availableItems.firstWhere(
      (item) => item.barcode == barcode,
      orElse: () => ItemModel(id: '', name: '', price: 0, isAvailable: false),
    );

    if (matchedItem.id.isNotEmpty) {
      // SUCCESS: Item exists, add to cart
      HapticFeedback.mediumImpact();
      final success = ref.read(cartProvider.notifier).addItem(matchedItem);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Added ${matchedItem.name} to checkout (₹${matchedItem.price.toStringAsFixed(0)})'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${matchedItem.name}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // QUICK ADD: Item does not exist. Show the Quick Add bottom sheet.
      _showQuickAddItemSheet(context, ref, barcode, l10n);
    }
  }

  void _showQuickAddItemSheet(BuildContext context, WidgetRef ref, String barcode, l10n) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final nameController = TextEditingController();
    
    // If it's our Hide & Seek demo barcode, pre-fill it for a premium, magical experience!
    if (barcode == '8901725181223') {
      nameController.text = 'Hide & Seek Biscuits';
    }

    final priceController = TextEditingController();
    final categoryController = TextEditingController(text: 'Snacks');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: Colors.orange,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Quick Register Product',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Barcode "$barcode" is not in items database. Quick register to add it to checkout!',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildDialogTextField(
                        controller: nameController,
                        label: 'Product Name',
                        icon: Icons.title_rounded,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDialogTextField(
                        controller: priceController,
                        label: 'Selling Price (₹)',
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDialogTextField(
                        controller: categoryController,
                        label: 'Category (Optional)',
                        icon: Icons.category_rounded,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 24),
                      
                      ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text.trim()) ?? 0;
                          
                          if (name.isNotEmpty && price > 0) {
                            setModalState(() => isSaving = true);
                            
                            final itemId = DateTime.now().millisecondsSinceEpoch.toString();
                            
                            final newItem = ItemModel(
                              id: itemId,
                              name: name,
                              price: price,
                              category: categoryController.text.isNotEmpty ? categoryController.text.trim() : null,
                              isAvailable: true,
                              barcode: barcode,
                            );

                            // Save item to inventory catalog database
                            await ref.read(itemsProvider.notifier).addItem(newItem);
                            // Add item to checkout cart immediately
                            ref.read(cartProvider.notifier).addItem(newItem);
                            
                            HapticFeedback.heavyImpact();
                            if (context.mounted) {
                              Navigator.pop(context);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Successfully registered and added $name!'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            HapticFeedback.vibrate();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: isSaving 
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                              )
                            : const Text(
                                'REGISTER & ADD TO CHECKOUT',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGracePeriodBanner(BuildContext context, int daysRemaining, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[800]!,
            Colors.orange[600]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.translate('grace_banner_message', args: {'days': daysRemaining.toString()}),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/profile/renewal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              l10n.translate('renew'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialReminderBanner(BuildContext context, int daysRemaining, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[800]!,
            Colors.blue[600]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.translate('trial_reminder_banner_message', args: {'days': daysRemaining.toString()}),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/profile/renewal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              l10n.translate('renew'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

