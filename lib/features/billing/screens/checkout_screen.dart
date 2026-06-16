import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../data/models/order_model.dart';
import '../widgets/sale_success_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/cart_provider.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/shop_model.dart';
import '../../printer/providers/printer_provider.dart';
import '../../printer/services/printer_service.dart';
import '../services/whatsapp_service.dart';
import '../../../core/services/razorpay_service.dart';
import '../../subscription/services/subscription_service.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  bool _showQR = false;
  String _selectedPaymentMethod = 'cash';
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late RazorpayService _razorpayService;

  @override
  void initState() {
    super.initState();
    final billsState = ref.read(cartProvider);
    final selectedBill = billsState.selectedBill;
    _phoneController = TextEditingController(
      text: selectedBill.customerPhone ?? '',
    );
    _nameController = TextEditingController();

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

    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);
    try {
      final order = await ref
          .read(cartProvider.notifier)
          .completeBill(
            paymentMethod: 'Razorpay',
            phone: _phoneController.text.trim(),
          );
      if (order != null) {
        _showSuccessDialog(order);
      } else {
        throw Exception('Order could not be generated.');
      }
    } catch (e) {
      debugPrint('❌ Razorpay checkout error: $e');
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(OrderModel order) {
    HapticFeedback.heavyImpact();

    // Auto print if autoPrintAfterSale is enabled
    final settingsState = ref.read(printerSettingsProvider);
    final printerService = ref.read(printerServiceProvider);
    final shop = ref.read(shopProvider).shop;

    if (settingsState.settings.autoPrintAfterSale && settingsState.connectionStatus.isConnected) {
      printerService.printOrder(
        order: order,
        settings: settingsState.settings,
        storeName: shop?.name,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleSuccessDialog(
        order: order,
        onPrint: () async {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printing invoice...'),
              duration: Duration(seconds: 1),
            ),
          );
          
          final success = await printerService.printOrder(
            order: order,
            settings: settingsState.settings,
            storeName: shop?.name,
          );
          
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Print failed. Check printer connection.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Checkout Failed', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            error.contains('Exception:') ? error.replaceAll('Exception: ', '') : 'An unexpected error occurred during checkout. Please try again.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '❌ Payment Failed: ${response.message ?? "Unknown error"}',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billsState = ref.watch(cartProvider);
    final bill = billsState.selectedBill;
    final shop = ref.watch(shopProvider).shop;
    final token = ref.watch(tokenProvider);
    final l10n = ref.watch(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Tablet logic removed

    if (l10n == null) return const Scaffold();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              // Decorative background circles
              ..._buildBackgroundCircles(primaryColor),

              // Main content
              Column(
                children: [
                  _buildHeader(bill, primaryColor, l10n),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _slideAnimation,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildOrderSummary(
                                      bill,
                                      primaryColor,
                                      l10n,
                                    ),
                                    const SizedBox(height: 20),
                                    if (_showQR && shop?.upiId != null)
                                      _buildQRCodeSection(
                                        shop,
                                        bill,
                                        primaryColor,
                                      ),
                                    if (!_showQR)
                                      _buildPaymentMethods(primaryColor, l10n),
                                    const SizedBox(height: 20),
                                    _buildCustomerSection(primaryColor, l10n),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 200),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom action panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomAction(
                  bill,
                  token,
                  primaryColor,
                  l10n,
                  shop,
                ),
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
    CartBill bill,
    Color primaryColor,
    AppLocalizations? l10n,
  ) {
    final isPaid = bill.isPaid;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: cs.onSurface,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.token_rounded, size: 14, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  bill.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPaid
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : Colors.orange,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(
    dynamic bill,
    Color primaryColor,
    AppLocalizations? l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: bill.items.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, color: cs.outlineVariant.withOpacity(0.2)),
            ),
            itemBuilder: (context, index) {
              final item = bill.items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(cartProvider.notifier)
                                  .removeItem(item.item);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 2,
                                  )
                                ]
                              ),
                              child: Icon(
                                Icons.remove_rounded,
                                size: 14,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final success = ref.read(cartProvider.notifier).addItem(item.item);
                              if (!success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Insufficient stock for ${item.item.name}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } else {
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 2,
                                  )
                                ]
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${item.item.price.toStringAsFixed(0)} each',
                            style: TextStyle(
                              color: cs.onSurfaceVariant.withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${item.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '₹${bill.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(Color primaryColor, l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.payment_rounded,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildPaymentOption(
                     title: 'Cash',
                     icon: Icons.money_rounded,
                     isSelected: _selectedPaymentMethod == 'cash',
                     onTap: () => setState(() {
                       _selectedPaymentMethod = 'cash';
                       _showQR = false;
                     }),
                     color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentOption(
                     title: 'UPI',
                     icon: Icons.qr_code_scanner_rounded,
                     isSelected: _selectedPaymentMethod == 'upi',
                     onTap: () {
                       setState(() {
                         _selectedPaymentMethod = 'upi';
                         _showQR = true;
                       });
                     },
                     color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.06) : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : cs.outlineVariant.withOpacity(0.4),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : cs.onSurfaceVariant.withOpacity(0.6),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : cs.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(
    ShopModel? shop,
    dynamic bill,
    Color primaryColor,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SCAN & PAY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant.withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _showQR = false),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: QrImageView(
                data: 'upi://pay?pa=${shop?.upiId ?? ''}&pn=${Uri.encodeComponent(shop?.name ?? '')}&am=${bill.total.toStringAsFixed(2)}&cu=INR',
                version: QrVersions.auto,
                size: 160.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: cs.onSurface,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            shop?.upiId ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(Color primaryColor, l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'CUSTOMER DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _nameController,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Customer Name (Optional)',
                labelStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
                prefixIcon: Icon(
                  Icons.person_rounded,
                  color: primaryColor.withOpacity(0.7),
                  size: 20,
                ),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TextField(
              controller: _phoneController,
              onChanged: (val) => ref.read(cartProvider.notifier).setCustomerPhone(val),
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Customer Phone Number',
                labelStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: primaryColor.withOpacity(0.7),
                  size: 20,
                ),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    CartBill bill,
    int token,
    Color primaryColor,
    AppLocalizations l10n,
    ShopModel? shop,
  ) {
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(
            children: [
              if (hasPhone && shop != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Builder(
                    builder: (context) => Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF25D366).withOpacity(0.2),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final subscription = ref.read(subscriptionProvider);
                            if (!subscription.isActive) {
                              showSubscriptionExpiredDialog(context);
                              return;
                            }
                            HapticFeedback.heavyImpact();
                            final box = context.findRenderObject() as RenderBox?;
                            final rect = box != null
                                ? box.localToGlobal(Offset.zero) & box.size
                                : null;

                            try {
                              await WhatsappService.sendBill(
                                shop: shop,
                                cart: bill.items,
                                total: bill.total,
                                token: token,
                                phone: _phoneController.text.trim(),
                                customerName: _nameController.text.trim(),
                                sharePositionOrigin: rect,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Color(0xFF25D366),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final subscription = ref.read(subscriptionProvider);
                            if (!subscription.isActive) {
                              showSubscriptionExpiredDialog(context);
                              return;
                            }
                            HapticFeedback.mediumImpact();
                            setState(() => _isProcessing = true);
                            try {
                              final order = await ref
                                  .read(cartProvider.notifier)
                                  .completeBill(
                                    paymentMethod: _selectedPaymentMethod == 'cash'
                                        ? 'Cash'
                                        : 'UPI',
                                    phone: _phoneController.text.trim(),
                                  );
                              if (order != null) {
                                _showSuccessDialog(order);
                              } else {
                                throw Exception('Order could not be generated.');
                              }
                            } catch (e) {
                              debugPrint('❌ Error during checkout: $e');
                              _showErrorDialog(e.toString());
                            } finally {
                              if (mounted) {
                                  setState(() => _isProcessing = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryColor.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'COMPLETE TRANSACTION',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
