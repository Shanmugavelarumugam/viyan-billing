import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/razorpay_service.dart';
import '../services/subscription_service.dart';

class PlanRenewalScreen extends ConsumerStatefulWidget {
  const PlanRenewalScreen({super.key});

  @override
  ConsumerState<PlanRenewalScreen> createState() => _PlanRenewalScreenState();
}

class _PlanRenewalScreenState extends ConsumerState<PlanRenewalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  String _selectedPlan = 'pro'; // Default to Pro as it is recommended/popular
  late RazorpayService _razorpayService;

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
    _slideAnimation = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ref.read(subscriptionProvider.notifier).renewPlan(
      _selectedPlan == 'basic' ? 'Basic Plan' : 'Pro Plan',
      30,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('✅ Subscription Active! Payment ID: ${response.paymentId}'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      context.go('/');
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('❌ Payment Failed: ${response.message ?? "Unknown error"}'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (loc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }


    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: 0.02),
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
                            _buildHeader(primaryColor),
                            _buildCurrentPlanCard(primaryColor, loc),
                            const SizedBox(height: 24),
                            
                            // Plan Toggle Selector
                            _buildPlanToggle(primaryColor, loc),
                            const SizedBox(height: 24),
                            
                            // Section Title
                            _buildSectionTitle(
                              loc.translate('choose_plan'),
                              primaryColor,
                            ),
                            const SizedBox(height: 16),
                            
                            // Comparison Table
                            _buildComparisonTable(primaryColor, loc),
                            
                            const SizedBox(height: 140), // Spacing for bottom sheet
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom payment summary action
              Align(
                alignment: Alignment.bottomCenter,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBottomAction(primaryColor, loc),
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
                primaryColor.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 150,
        left: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Subscription renewal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(Color primaryColor, AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('current_plan_title'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.translate('active_plan', args: {'plan': 'Basic'}),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.translate('expires_in', args: {'days': '15'}),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              loc.translate('active_status'),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToggle(Color primaryColor, AppLocalizations loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleTab(
              title: 'Basic Plan',
              subtitle: '₹199/mo',
              isSelected: _selectedPlan == 'basic',
              selectedColor: Colors.blue.shade600,
              onTap: () => setState(() => _selectedPlan = 'basic'),
            ),
          ),
          Expanded(
            child: _buildToggleTab(
              title: 'Pro Plan',
              subtitle: '₹599/mo',
              isSelected: _selectedPlan == 'pro',
              selectedColor: Colors.purple.shade600,
              onTap: () => setState(() => _selectedPlan = 'pro'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
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
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(Color primaryColor, AppLocalizations loc) {
    final isBasicSelected = _selectedPlan == 'basic';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Table Header Row
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Feature Comparison',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isBasicSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'BASIC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: !isBasicSelected ? Colors.purple.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Feature Rows
            _FeatureRow(
              feature: loc.translate('unlimited_bills'),
              basicValue: const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
              proValue: const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 18),
              isEven: false,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: loc.translate('whatsapp_reports'),
              basicValue: const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
              proValue: const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 18),
              isEven: true,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: 'Analytics Dashboard',
              basicValue: const Text('Basic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              proValue: const Text('Advanced', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
              isEven: false,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: loc.translate('inventory_management'),
              basicValue: Icon(Icons.cancel_rounded, color: Colors.grey[300], size: 18),
              proValue: const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 18),
              isEven: true,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: 'Customer Loyalty',
              basicValue: Icon(Icons.cancel_rounded, color: Colors.grey[300], size: 18),
              proValue: const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 18),
              isEven: false,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: 'Branch Support',
              basicValue: const Text('1 Branch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              proValue: const Text('3 Branches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
              isEven: true,
              isBasicSelected: isBasicSelected,
            ),
            _FeatureRow(
              feature: 'Customer Support',
              basicValue: const Text('Standard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
              proValue: const Text('24/7 Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
              isEven: false,
              isBasicSelected: isBasicSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(Color primaryColor, AppLocalizations loc) {
    final planPrices = {'basic': 199, 'pro': 599};
    final selectedPrice = planPrices[_selectedPlan] ?? 199;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.translate('total_amount'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '₹$selectedPrice',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _selectedPlan == 'basic' ? Colors.blue.shade700 : Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _razorpayService.openCheckout(
                    key: 'rzp_live_StUZupmMw4H4yc',
                    amount: selectedPrice.toDouble(),
                    name: 'Subscription Renewal',
                    description: 'Renewal for ${_selectedPlan.toUpperCase()} Plan',
                    contact: '9999999999',
                    email: 'billing@viyan.com',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPlan == 'basic' ? Colors.blue.shade600 : Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  loc.translate('proceed_payment'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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

class _FeatureRow extends StatelessWidget {
  final String feature;
  final Widget basicValue;
  final Widget proValue;
  final bool isEven;
  final bool isBasicSelected;

  const _FeatureRow({
    required this.feature,
    required this.basicValue,
    required this.proValue,
    required this.isEven,
    required this.isBasicSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isBasicSelected 
                    ? Colors.blue.withValues(alpha: 0.03)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: basicValue),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: !isBasicSelected 
                    ? Colors.purple.withValues(alpha: 0.03)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: proValue),
            ),
          ),
        ],
      ),
    );
  }
}
