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
    _animationController.forward();
    _autoSync();
  }

  void _autoSync() {
    Future.microtask(() async {
      if (!mounted) return;
      final box = Hive.box<OrderModel>('orders_box');
      if (box.isEmpty) _syncOrders();
    });
  }

  Future<void> _syncOrders() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final cloudOrders =
          await ref.read(firestoreRepositoryProvider).getOrdersOnce();
      if (!mounted) return;
      if (cloudOrders.isNotEmpty) {
        final box = Hive.box<OrderModel>('orders_box');
        await box.clear();
        await box.addAll(cloudOrders);
      }
    } catch (e) {
      debugPrint("Error syncing orders: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
    switch (_selectedFilter) {
      case ReportFilter.today:
        return allOrders.where((o) => !o.timestamp.isBefore(today)).toList();
      case ReportFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return allOrders
            .where((o) => !o.timestamp.isBefore(yesterday) && o.timestamp.isBefore(today))
            .toList();
      case ReportFilter.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return allOrders.where((o) => !o.timestamp.isBefore(startOfWeek)).toList();
      case ReportFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return allOrders.where((o) => !o.timestamp.isBefore(startOfMonth)).toList();
      case ReportFilter.custom:
        if (_customRange == null) return [];
        final startDate = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
        final endDate = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
        return allOrders
            .where((o) => !o.timestamp.isBefore(startDate) && !o.timestamp.isAfter(endDate))
            .toList();
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, onSurface: Colors.black87),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _customRange) {
      setState(() { _customRange = picked; _selectedFilter = ReportFilter.custom; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    final pc = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (l10n == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final box = Hive.box<OrderModel>('orders_box');

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<OrderModel> box, _) {
        final allOrders = box.values.toList();
        final orders = _filterOrders(allOrders);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pc.withValues(alpha: 0.05),
                  isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(top: -100, right: -60, child: _bgCircle(pc, 200, 0.10)),
                  Positioned(bottom: 150, left: -70, child: _bgCircle(pc, 220, 0.06)),
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(children: [
                            _buildHeader(l10n, orders, pc),
                            const SizedBox(height: 24),
                            _buildQuickStats(orders, pc),
                            const SizedBox(height: 24),
                            _buildChartSection(allOrders, pc),
                            const SizedBox(height: 24),
                            _buildTopItems(orders, pc),
                            const SizedBox(height: 24),
                            _buildPaymentBreakdown(orders, pc),
                            const SizedBox(height: 24),
                            _buildPeakHours(orders, pc),
                            const SizedBox(height: 24),
                            _buildRecentOrders(orders, pc),
                            SizedBox(height: 100 + MediaQuery.paddingOf(context).bottom),
                          ]),
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

  Widget _bgCircle(Color c, double size, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withValues(alpha: opacity), Colors.transparent]),
        ),
      );

  // ─── CARD WRAPPER ───────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 5)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: child,
      );

  // ─── SECTION LABEL ──────────────────────────────────────────────
  Widget _sectionLabel(String label, IconData icon, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: c),
          ),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.7)),
        ]),
      );

  // ─── HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n, List<OrderModel> orders, Color pc) {
    final totalSales = orders.fold(0.0, (s, o) => s + o.total);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: pc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.analytics_rounded, color: pc, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.translate('reports'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 9, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _selectedFilter == ReportFilter.custom && _customRange != null
                        ? '${DateFormat('MMM dd').format(_customRange!.start)} – ${DateFormat('MMM dd').format(_customRange!.end)}'
                        : DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildFilter(l10n, pc)),
          const SizedBox(width: 10),
          _iconBtn(Icons.sync_rounded, pc, _syncOrders, _isSyncing),
          const SizedBox(width: 8),
          _buildShare(orders, l10n, pc),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [pc, pc.withValues(alpha: 0.72)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: pc.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 10))],
          ),
          child: Stack(children: [
            Positioned(top: -12, right: -12, child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
            )),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.trending_up_rounded, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 5),
                    Text('TOTAL SALES',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.7)),
                  ]),
                  const SizedBox(height: 5),
                  Text('₹${totalSales.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.4, height: 1.1)),
                  const SizedBox(height: 3),
                  Text('${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.55))),
                ]),
              ),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFilter(AppLocalizations l10n, Color pc) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ReportFilter>(
            isExpanded: true,
            value: _selectedFilter,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: pc, size: 17),
            style: TextStyle(color: pc, fontWeight: FontWeight.w600, fontSize: 11),
            onChanged: (v) {
              if (v != null && (v == ReportFilter.thisWeek || v == ReportFilter.thisMonth || v == ReportFilter.custom)) {
                if (!ref.read(subscriptionProvider).isActive) { showSubscriptionExpiredDialog(context); return; }
              }
              if (v == ReportFilter.custom) { _selectDateRange(context); }
              else if (v != null) { setState(() => _selectedFilter = v); }
            },
            items: [
              DropdownMenuItem(value: ReportFilter.today, child: Text(l10n.translate('today'))),
              DropdownMenuItem(value: ReportFilter.yesterday, child: Text(l10n.translate('yesterday'))),
              DropdownMenuItem(value: ReportFilter.thisWeek, child: Text(l10n.translate('this_week'))),
              DropdownMenuItem(value: ReportFilter.thisMonth, child: Text(l10n.translate('this_month'))),
              DropdownMenuItem(value: ReportFilter.custom, child: Text(l10n.translate('custom_range'))),
            ],
          ),
        ),
      );

  Widget _iconBtn(IconData icon, Color pc, VoidCallback onTap, [bool loading = false]) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: pc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: loading
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(pc)))
              : Icon(icon, color: pc, size: 18),
        ),
      );

  Widget _buildShare(List<OrderModel> orders, AppLocalizations l10n, Color pc) => Builder(
        builder: (ctx) => _iconBtn(Icons.share_rounded, pc, () {
          if (!ref.read(subscriptionProvider).isActive) { showSubscriptionExpiredDialog(context); return; }
          final shop = ref.read(shopProvider).shop;
          if (shop == null) return;
          final box = context.findRenderObject() as RenderBox?;
          WhatsappService.sendPdfReport(
            shop: shop, orders: orders,
            filterName: _getReportTitle(l10n),
            sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );
        }),
      );

  String _getReportTitle(AppLocalizations l10n) {
    switch (_selectedFilter) {
      case ReportFilter.today: return "TODAY'S REPORT";
      case ReportFilter.yesterday: return "YESTERDAY'S REPORT";
      case ReportFilter.thisWeek: return "WEEKLY REPORT";
      case ReportFilter.thisMonth: return "MONTHLY REPORT";
      case ReportFilter.custom: return "CUSTOM REPORT";
    }
  }

  // ─── QUICK STATS ──────────────────────────────────────────────
  Widget _buildQuickStats(List<OrderModel> orders, Color pc) {
    final txnCount = orders.length;
    final totalItems = orders.fold(0, (s, o) => s + o.items.fold(0, (a, i) => a + i.quantity));
    final totalRevenue = orders.fold(0.0, (s, o) => s + o.total);
    final avgTicket = txnCount > 0 ? totalRevenue / txnCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(child: _statCard(Icons.shopping_bag_rounded, '$txnCount', 'Transactions', pc)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.inventory_2_rounded, '$totalItems', 'Items sold', const Color(0xFF10B981))),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.receipt_rounded, '₹${avgTicket.toStringAsFixed(0)}', 'Avg ticket', const Color(0xFF0EA5E9))),
      ]),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.2)),
        ]),
      );

  // ─── SALES CHART ──────────────────────────────────────────────
  Widget _buildChartSection(List<OrderModel> allOrders, Color pc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<DateTime> dates;
    String title;
    switch (_selectedFilter) {
      case ReportFilter.thisWeek:
        final start = today.subtract(Duration(days: today.weekday - 1));
        dates = List.generate(7, (i) => start.add(Duration(days: i)));
        title = 'THIS WEEK';
        break;
      case ReportFilter.thisMonth:
        dates = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
        title = 'MONTHLY TREND';
        break;
      default:
        dates = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
        title = '7-DAY TREND';
    }
    final dailyTotals = dates.map((d) {
      final next = d.add(const Duration(days: 1));
      return allOrders
          .where((o) => !o.timestamp.isBefore(d) && o.timestamp.isBefore(next))
          .fold(0.0, (s, o) => s + o.total);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(title, Icons.trending_up_rounded, pc),
      const SizedBox(height: 12),
      _card(child: DailySalesChart(dailyTotals: dailyTotals, dates: dates)),
    ]);
  }

  // ─── TOP SELLING ITEMS ────────────────────────────────────────
  Widget _buildTopItems(List<OrderModel> orders, Color pc) {
    final itemMap = <String, int>{};
    for (final o in orders) {
      for (final ci in o.items) {
        itemMap[ci.item.name] = (itemMap[ci.item.name] ?? 0) + ci.quantity;
      }
    }
    final sorted = itemMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final maxQty = top.first.value;
    final totalQty = top.fold(0, (s, e) => s + e.value);
    final rankColors = [pc, const Color(0xFF0EA5E9), const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFF59E0B)];
    final medals = ['1st', '2nd', '3rd', '4th', '5th'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('TOP SELLING ITEMS', Icons.star_rounded, pc),
      const SizedBox(height: 12),
      _card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(children: [
            Row(children: [
              Text('Item', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
              const Spacer(),
              SizedBox(
                width: 52,
                child: Text('Qty', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text('%', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
              ),
            ]),
            const SizedBox(height: 12),
            ...List.generate(top.length, (i) {
              final e = top[i];
              final pct = totalQty > 0 ? (e.value / totalQty * 100) : 0.0;
              final c = rankColors[i % rankColors.length];
              return Padding(
                padding: EdgeInsets.only(bottom: i < top.length - 1 ? 12 : 0),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                    child: Center(child: Text(medals[i], style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: c))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: e.value / maxQty,
                          backgroundColor: c.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(c),
                          minHeight: 4,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 44,
                    child: Text('${e.value}', textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c)),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 38,
                    child: Text('${pct.toStringAsFixed(0)}%', textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.grey[500])),
                  ),
                ]),
              );
            }),
          ]),
        ),
      ),
    ]);
  }

  // ─── PAYMENT BREAKDOWN ────────────────────────────────────────
  Widget _buildPaymentBreakdown(List<OrderModel> orders, Color pc) {
    double cashAmt = 0, upiAmt = 0;
    int cashCount = 0, upiCount = 0;
    for (final o in orders) {
      if (o.paymentMethod.toLowerCase() == 'cash') { cashAmt += o.total; cashCount++; }
      else { upiAmt += o.total; upiCount++; }
    }
    final totalAmt = cashAmt + upiAmt;
    final totalCount = cashCount + upiCount;
    final cashFrac = totalAmt > 0 ? cashAmt / totalAmt : 0.0;
    final upiFrac = totalAmt > 0 ? upiAmt / totalAmt : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('PAYMENT BREAKDOWN', Icons.payments_rounded, const Color(0xFF0EA5E9)),
      const SizedBox(height: 12),
      _card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              Expanded(child: _payMethod(Icons.money_rounded, 'Cash', cashAmt, cashCount, cashFrac, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _payMethod(Icons.qr_code_rounded, 'UPI', upiAmt, upiCount, upiFrac, const Color(0xFF6366F1))),
            ]),
            if (totalCount > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: Row(children: [
                    Expanded(
                      flex: (cashFrac * 100).round().clamp(1, 100),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5), bottomLeft: Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: (upiFrac * 100).round().clamp(1, 100),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(5), bottomRight: Radius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _legendDot(const Color(0xFF10B981), 'Cash'),
                const Spacer(),
                Text('${(cashFrac * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                const SizedBox(width: 24),
                _legendDot(const Color(0xFF6366F1), 'UPI'),
                const Spacer(),
                Text('${(upiFrac * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600])),
              ]),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      ]);

  Widget _payMethod(IconData icon, String label, double amount, int count, double frac, Color c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: c),
            ),
            const Spacer(),
            if (frac > 0)
              Text('${(frac * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
          ]),
          const SizedBox(height: 10),
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c, height: 1.1)),
          Text('$count ${count == 1 ? 'transaction' : 'transactions'}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey[500])),
        ]),
      );

  // ─── PEAK HOURS ───────────────────────────────────────────────
  Widget _buildPeakHours(List<OrderModel> orders, Color pc) {
    String range = '—';
    int peakCount = 0;
    double peakRevenue = 0;

    if (orders.isNotEmpty) {
      final hourMap = <int, List<double>>{};
      for (final o in orders) {
        final h = o.timestamp.hour;
        hourMap.putIfAbsent(h, () => []);
        hourMap[h]!.add(o.total);
      }
      if (hourMap.isNotEmpty) {
        final peak = hourMap.entries.reduce((a, b) => a.value.length > b.value.length ? a : b);
        peakCount = peak.value.length;
        peakRevenue = peak.value.fold(0.0, (s, v) => s + v);
        final st = peak.key % 12 == 0 ? 12 : peak.key % 12;
        final en = (peak.key + 1) % 12 == 0 ? 12 : (peak.key + 1) % 12;
        final ap = peak.key >= 12 ? 'PM' : 'AM';
        final ea = (peak.key + 1) >= 24 ? 'AM' : ((peak.key + 1) >= 12 ? 'PM' : 'AM');
        range = '$st $ap – $en $ea';
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('PEAK HOURS', Icons.flash_on_rounded, const Color(0xFFF59E0B)),
      const SizedBox(height: 12),
      _card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(range, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Row(children: [
                  _badge('$peakCount orders', const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _badge('₹${peakRevenue.toStringAsFixed(0)}', pc),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _badge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
      );

  // ─── RECENT ORDERS ────────────────────────────────────────────
  Widget _buildRecentOrders(List<OrderModel> orders, Color pc) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final recent = [...orders]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final items = recent.take(10).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('RECENT ORDERS', Icons.receipt_long_rounded, const Color(0xFF8B5CF6)),
      const SizedBox(height: 12),
      _card(
        child: Column(children: items.map((o) {
          final isCash = o.paymentMethod.toLowerCase() == 'cash';
          final itemCount = o.items.fold(0, (s, i) => s + i.quantity);
          return _orderTile(o.tokenNumber.toString(), o.total, o.timestamp, isCash, itemCount);
        }).toList()),
      ),
    ]);
  }

  Widget _orderTile(String token, double amount, DateTime ts, bool isCash, int itemsCount) {
    final payColor = isCash ? const Color(0xFF10B981) : const Color(0xFF6366F1);
    final payIcon = isCash ? Icons.money_rounded : Icons.qr_code_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[50]!, width: 1)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: payColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(payIcon, size: 17, color: payColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#$token', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isCash ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isCash ? 'Cash' : 'UPI',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: payColor)),
              ),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 8, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text(DateFormat('hh:mm a').format(ts),
                  style: TextStyle(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Icon(Icons.inventory_2_rounded, size: 8, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text('$itemsCount items',
                  style: TextStyle(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        Text('₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
      ]),
    );
  }
}
