import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

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
    final state = ref.watch(cartProvider);
    final items = ref.watch(itemsProvider);
    final shop = ref.watch(shopProvider).shop;
    final l10n = ref.watch(localizationProvider);
    final selectedBill = state.selectedBill;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (l10n == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final availableItems = items.where((i) => i.isAvailable).toList();
    final filteredItems = _selectedCategory == 'All'
        ? availableItems
        : availableItems.where((i) => i.category == _selectedCategory).toList();

    final categories = [
      'All',
      ...items.map((i) => i.category ?? 'Uncategorized').toSet(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, shop, l10n),
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
              // Decorative background circles
              ..._buildBackgroundCircles(),

              // Main content
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          _buildHeader(shop, l10n, selectedBill),
                          _buildBillSwitcher(state, ref, l10n),
                          _buildCategorySection(categories, l10n),
                          _buildQuickItemsRow(availableItems, ref),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      120 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: _buildItemsGrid(
                      filteredItems,
                      selectedBill,
                      ref,
                      isTablet,
                    ),
                  ),
                ],
              ),

              // Floating cart
              if (selectedBill.items.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildFloatingCart(ref, selectedBill, shop, l10n),
                    ),
                  ),
                ),
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
                onTap: () => _showVoiceBillingSheet(context, ref, l10n),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
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
              onTap: () => ref.read(cartProvider.notifier).addBill(),
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

  Widget _buildQuickItemsRow(List<ItemModel> items, WidgetRef ref) {
    final quickItems = items.where((i) => i.isAvailable).take(4).toList();

    if (quickItems.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 140,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: quickItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = quickItems[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(cartProvider.notifier).addItem(item);
            },
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[100]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: _buildItemImage(item, size: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
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
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addItem(item);
      },
      onLongPress: () {
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

  Widget _buildDrawer(BuildContext context, ShopModel? shop, AppLocalizations? l10n) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(shop),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.receipt_long_rounded,
                  label: l10n?.translate('billing') ?? 'Billing',
                  onTap: () {
                    Navigator.pop(context);
                  },
                  isSelected: true,
                ),
                _buildDrawerItem(
                  icon: Icons.bar_chart_rounded,
                  label: l10n?.translate('reports') ?? 'Reports',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/reports');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2_rounded,
                  label: l10n?.translate('items') ?? 'Items',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/items');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  label: l10n?.translate('profile') ?? 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile/edit');
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Viyan Billing v1.0.0',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(ShopModel? shop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 60 + MediaQuery.paddingOf(context).top, 24, 24),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.store_rounded,
              color: _primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            shop?.name ?? 'Your Shop',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shop?.address ?? 'Store Address',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isSelected ? _primaryColor : Colors.grey[600],
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? _primaryColor : const Color(0xFF1E293B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        tileColor: isSelected ? _primaryColor.withValues(alpha: 0.1) : Colors.transparent,
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
                            for (final res in results) {
                              for (int i = 0; i < res.quantity; i++) {
                                ref
                                    .read(cartProvider.notifier)
                                    .addItem(res.item);
                              }
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Added ${results.length} items!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
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
}
