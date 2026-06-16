import 'package:flutter/material.dart';
import '../../../data/models/order_model.dart';

/// High-speed POS sale completion dialog optimised for pharmacy/retail cashier
/// workflow.  ~25 % shorter than a standard dialog.  Information hierarchy:
///
///   1. Success icon  (animated entrance with glowing concentric rings)
///   2. Total amount  (hero — largest, bold, primary colour)
///   3. Invoice • Items • Payment  (compact single line)
///   4. [Print] [Done]  (equal visual weight, dense pill buttons)
///   5. Auto-close countdown  (3 s animated progress bar at the bottom)
///
/// Design decisions:
///   — No product list (deferred to receipt print).
///   — Tight vertical gaps; POS‑dense rhythm.
///   — Print cancels auto‑close; Done or timer pops both dialog & checkout screen.
class SaleSuccessDialog extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onPrint;

  const SaleSuccessDialog({
    super.key,
    required this.order,
    required this.onPrint,
  });

  @override
  State<SaleSuccessDialog> createState() => _SaleSuccessDialogState();
}

class _SaleSuccessDialogState extends State<SaleSuccessDialog>
    with TickerProviderStateMixin {
  bool _printClicked = false;
  late final AnimationController _animCtrl;
  late final AnimationController _countdownCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );

    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animCtrl.forward();
    
    // Start countdown animation
    _countdownCtrl.reverse(from: 1.0).then((_) {
      if (mounted && !_printClicked) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _countdownCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────

  void _handlePrint() {
    _countdownCtrl.stop();
    setState(() => _printClicked = true);
    widget.onPrint();
  }

  void _handleDone() {
    _countdownCtrl.stop();
    Navigator.of(context).pop();
  }

  // ── Payment icon helper ────────────────────────────────────────────

  static IconData _paymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'upi':
        return Icons.qr_code_scanner_rounded;
      case 'razorpay':
      case 'online':
        return Icons.wifi_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final order = widget.order;
    final totalItems = order.items.fold<int>(0, (s, i) => s + i.quantity);
    final invoiceText = 'Invoice #${order.tokenNumber}';
    final itemsText = '$totalItems ${totalItems == 1 ? 'Item' : 'Items'}';
    final payMethod = order.paymentMethod;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primary.withOpacity(0.03),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 1. Animated success icon with glowing concentric rings ──
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _fadeAnim.value,
                        child: Transform.scale(
                          scale: _scaleAnim.value,
                          child: child,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 2. Title ──
                    Text(
                      'Sale Completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant.withOpacity(0.8),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── 3. Hero amount ──
                    Text(
                      '₹${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 4. Compact info line ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_paymentIcon(payMethod), size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            '$invoiceText  •  $itemsText  •  $payMethod',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 4.5 Items bought list ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: order.items.length,
                          separatorBuilder: (_, __) => Divider(height: 12, color: cs.outlineVariant.withOpacity(0.2)),
                          itemBuilder: (context, idx) {
                            final cartItem = order.items[idx];
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cartItem.item.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${cartItem.quantity}x',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '₹${cartItem.total.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 5. Buttons ──
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _handlePrint,
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('Print', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _handleDone,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.onSurface,
                                side: BorderSide(color: cs.outlineVariant, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // ── 6. Animated countdown progress bar at the bottom ──
              if (!_printClicked)
                AnimatedBuilder(
                  animation: _countdownCtrl,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _countdownCtrl.value,
                    minHeight: 4,
                    backgroundColor: cs.primary.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary.withOpacity(0.4)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


