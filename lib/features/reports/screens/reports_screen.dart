import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../billing/services/whatsapp_service.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../subscription/services/subscription_service.dart';
import '../../../../data/repositories/firestore_repository.dart';
import '../../../data/models/order_model.dart';
import '../widgets/daily_sales_chart.dart';

enum ReportFilter { today, yesterday, thisWeek, thisMonth, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  ReportFilter _selectedFilter = ReportFilter.today;
  DateTimeRange? _customRange;
  bool _isSyncing = false;

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
    _slideAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _autoSync();
  }

  void _autoSync() {
    // Defer Hive read to after first frame to avoid blocking startup
    Future.microtask(() async {
      if (!mounted) return;
      final box = Hive.box<OrderModel>('orders_box');
      if (box.isEmpty) {
        _syncOrders();
      }
    });
  }

  Future<void> _syncOrders() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final cloudOrders = await ref
          .read(firestoreRepositoryProvider)
          .getOrdersOnce();
      if (!mounted) return;
      if (cloudOrders.isNotEmpty) {
        final box = Hive.box<OrderModel>('orders_box');
        await box.clear();
        await box.addAll(cloudOrders);
      }
    } catch (e) {
      debugPrint("❌ Error syncing orders: $e");
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> allOrders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<OrderModel> results = [];
    switch (_selectedFilter) {
      case ReportFilter.today:
        results = allOrders.where((o) => !o.timestamp.isBefore(today)).toList();
        break;
      case ReportFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        results = allOrders
            .where(
              (o) =>
                  !o.timestamp.isBefore(yesterday) &&
                  o.timestamp.isBefore(today),
            )
            .toList();
        break;
      case ReportFilter.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        results = allOrders
            .where((o) => !o.timestamp.isBefore(startOfWeek))
            .toList();
        break;
      case ReportFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        results = allOrders
            .where((o) => !o.timestamp.isBefore(startOfMonth))
            .toList();
        break;
      case ReportFilter.custom:
        if (_customRange == null) {
          results = [];
        } else {
          final startDate = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          );
          final endDate = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
          );
          results = allOrders
              .where(
                (o) =>
                    !o.timestamp.isBefore(startDate) &&
                    !o.timestamp.isAfter(endDate),
              )
              .toList();
        }
        break;
    }

    debugPrint("📊 Filter: ${_selectedFilter.name}, Orders: ${results.length}");
    return results;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _customRange) {
      setState(() {
        _customRange = picked;
        _selectedFilter = ReportFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (l10n == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final box = Hive.box<OrderModel>('orders_box');

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<OrderModel> box, _) {
        final allOrders = box.values.toList();
        final filteredOrders = _filterOrders(allOrders);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withValues(alpha: 0.03),
                  Colors.white,
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Decorative background elements
                  ..._buildBackgroundCircles(primaryColor),

                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _slideAnimation,
                            child: Column(
                              children: [
                                _buildHeader(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildStatsSection(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildChartSection(allOrders, primaryColor),
                                const SizedBox(height: 24),
                                _buildTopItemsSection(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildPaymentSection(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildPeakTimeSection(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                const SizedBox(height: 24),
                                _buildRecentOrdersSection(
                                  l10n,
                                  filteredOrders,
                                  primaryColor,
                                ),
                                SizedBox(
                                  height:
                                      100 +
                                      MediaQuery.paddingOf(context).bottom,
                                ),
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
      },
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
                primaryColor.withValues(alpha: 0.12),
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
                primaryColor.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    final totalSales = orders.fold(0.0, (sum, o) => sum + o.total);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('reports'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 10,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _selectedFilter == ReportFilter.custom &&
                                    _customRange != null
                                ? '${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}'
                                : DateFormat(
                                    'MMMM dd, yyyy',
                                  ).format(DateTime.now()),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
          const SizedBox(height: 16),
          // Actions Row: Filter dropdown & Buttons
          Row(
            children: [
              Expanded(child: _buildFilterDropdown(l10n, primaryColor)),
              const SizedBox(width: 12),
              _buildSyncButton(primaryColor),
              const SizedBox(width: 8),
              _buildShareButton(orders, l10n, primaryColor),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL SALES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalSales.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(AppLocalizations l10n, Color primaryColor) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ReportFilter>(
          isExpanded: true,
          value: _selectedFilter,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: primaryColor,
            size: 18,
          ),
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          onChanged: (ReportFilter? newValue) {
            if (newValue != null &&
                (newValue == ReportFilter.thisWeek ||
                 newValue == ReportFilter.thisMonth ||
                 newValue == ReportFilter.custom)) {
              final subscription = ref.read(subscriptionProvider);
              if (!subscription.isActive) {
                showSubscriptionExpiredDialog(context);
                return;
              }
            }
            if (newValue == ReportFilter.custom) {
              _selectDateRange(context);
            } else if (newValue != null) {
              setState(() => _selectedFilter = newValue);
            }
          },
          items: [
            DropdownMenuItem(
              value: ReportFilter.today,
              child: Text(l10n.translate('today')),
            ),
            DropdownMenuItem(
              value: ReportFilter.yesterday,
              child: Text(l10n.translate('yesterday')),
            ),
            DropdownMenuItem(
              value: ReportFilter.thisWeek,
              child: Text(l10n.translate('this_week')),
            ),
            DropdownMenuItem(
              value: ReportFilter.thisMonth,
              child: Text(l10n.translate('this_month')),
            ),
            DropdownMenuItem(
              value: ReportFilter.custom,
              child: Text(l10n.translate('custom_range')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(Color primaryColor) {
    return GestureDetector(
      onTap: _syncOrders,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _isSyncing
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : Icon(Icons.sync_rounded, color: primaryColor, size: 22),
      ),
    );
  }

  String _getReportTitle(AppLocalizations l10n) {
    switch (_selectedFilter) {
      case ReportFilter.today:
        return "TODAY'S REPORT";
      case ReportFilter.yesterday:
        return "YESTERDAY'S REPORT";
      case ReportFilter.thisWeek:
        return "WEEKLY REPORT";
      case ReportFilter.thisMonth:
        return "MONTHLY REPORT";
      case ReportFilter.custom:
        return "CUSTOM REPORT";
    }
  }

  Widget _buildShareButton(
    List<OrderModel> orders,
    AppLocalizations l10n,
    Color primaryColor,
  ) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          final subscription = ref.read(subscriptionProvider);
          if (!subscription.isActive) {
            showSubscriptionExpiredDialog(context);
            return;
          }
          final shop = ref.read(shopProvider).shop;
          if (shop != null) {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            final Rect? rect = box != null
                ? box.localToGlobal(Offset.zero) & box.size
                : null;

            WhatsappService.sendPdfReport(
              shop: shop,
              orders: orders,
              filterName: _getReportTitle(l10n),
              sharePositionOrigin: rect,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.share_rounded, color: primaryColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    return const SizedBox.shrink();
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<OrderModel> allOrders, Color primaryColor) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<DateTime> dates;
    String trendTitle = 'SALES TREND';

    switch (_selectedFilter) {
      case ReportFilter.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        dates = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
        trendTitle = 'THIS WEEK';
        break;
      case ReportFilter.thisMonth:
        // Show last 7 days of the month (current trend)
        dates = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
        trendTitle = 'MONTHLY TREND';
        break;
      default:
        dates = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
        trendTitle = '7-DAY TREND';
    }

    final dailyTotals = <double>[];

    for (var date in dates) {
      final nextDay = date.add(const Duration(days: 1));
      final total = allOrders
          .where(
            (o) => !o.timestamp.isBefore(date) && o.timestamp.isBefore(nextDay),
          )
          .fold(0.0, (sum, o) => sum + o.total);
      dailyTotals.add(total);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trendTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DailySalesChart(dailyTotals: dailyTotals, dates: dates),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemsSection(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    final itemMap = <String, int>{};
    for (var order in orders) {
      for (var cartItem in order.items) {
        final name = cartItem.item.name;
        itemMap[name] = (itemMap[name] ?? 0) + cartItem.quantity;
      }
    }

    final sortedItems = itemMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    if (topItems.isEmpty) return const SizedBox.shrink();

    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.red,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TOP ITEMS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(topItems.length, (index) {
                final entry = topItems[index];
                return Column(
                  children: [
                    _buildTopItemTile(
                      index + 1,
                      entry.key,
                      entry.value.toString(),
                      colors[index % colors.length],
                    ),
                    if (index < topItems.length - 1)
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Colors.grey[100],
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemTile(int rank, String name, String count, Color color) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
      trailing: Text(
        count,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildPaymentSection(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    final cashCount = orders
        .where((o) => o.paymentMethod.toLowerCase() == 'cash')
        .length;
    final upiCount = orders
        .where((o) => o.paymentMethod.toLowerCase() == 'upi')
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PAYMENT BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPaymentCard(
                  'Cash',
                  cashCount,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentCard(
                  'UPI',
                  upiCount,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
    String method,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              method == 'Cash' ? Icons.money_rounded : Icons.qr_code_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            method,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count Transaction${count == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakTimeSection(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    String peakRange = 'No data';
    int maxCount = 0;

    if (orders.isNotEmpty) {
      final hourMap = <int, int>{};
      for (var o in orders) {
        final hour = o.timestamp.hour;
        hourMap[hour] = (hourMap[hour] ?? 0) + 1;
      }

      int peakHour = hourMap.entries.isNotEmpty
          ? hourMap.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 0;

      maxCount = hourMap[peakHour] ?? 0;
      final start = peakHour % 12 == 0 ? 12 : peakHour % 12;
      final end = (peakHour + 1) % 12 == 0 ? 12 : (peakHour + 1) % 12;
      final ampm = peakHour >= 12 ? 'PM' : 'AM';
      final endAmpm = (peakHour + 1) >= 24
          ? 'AM'
          : ((peakHour + 1) >= 12 ? 'PM' : 'AM');
      peakRange = '$start $ampm – $end $endAmpm';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PEAK HOURS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peakRange,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$maxCount orders during this time',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection(
    AppLocalizations l10n,
    List<OrderModel> orders,
    Color primaryColor,
  ) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final sortedOrders = [...orders]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentOrders = sortedOrders.take(10).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECENT ORDERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: recentOrders.map((order) {
                final timeStr = DateFormat('hh:mm a').format(order.timestamp);
                return _buildRecentOrderTile(
                  order.tokenNumber.toString(),
                  '₹${order.total.toStringAsFixed(0)}',
                  timeStr,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrderTile(String token, String amount, String time) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '#$token',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      title: Text(
        amount,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    );
  }
}
