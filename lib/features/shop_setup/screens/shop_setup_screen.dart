import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../providers/shop_provider.dart';
import '../../../data/models/shop_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/localization/localization_provider.dart';

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _upiController = TextEditingController();
  final _addressController = TextEditingController();
  
  final _nameFocus = FocusNode();
  final _ownerFocus = FocusNode();
  final _upiFocus = FocusNode();
  final _addressFocus = FocusNode();
  
  String _selectedShopType = 'Tea Shop';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<String> _shopTypes = [
    'Tea Shop',
    'Food Truck',
    'Tiffin Stall',
    'Bakery',
    'Juice Shop',
    'Restaurant'
  ];

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

    _nameFocus.addListener(() => setState(() {}));
    _ownerFocus.addListener(() => setState(() {}));
    _upiFocus.addListener(() => setState(() {}));
    _addressFocus.addListener(() => setState(() {}));

    // Pre-fill owner name from auth state if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.fullName != null) {
        _ownerController.text = auth.fullName!;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _ownerController.dispose();
    _upiController.dispose();
    _addressController.dispose();
    _nameFocus.dispose();
    _ownerFocus.dispose();
    _upiFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter shop name');
      return;
    }

    HapticFeedback.mediumImpact();

    final authState = ref.read(authProvider);
    final shop = ShopModel(
      name: name,
      ownerName: _ownerController.text.trim(),
      shopType: _selectedShopType,
      upiId: _upiController.text.trim(),
      address: _addressController.text.trim(),
      email: authState.email,
      language: authState.preferredLanguage ?? 'ta',
      tokenStartNumber: 1, // Default value
      currency: '₹',
    );

    // Save Shop Profile
    await ref.read(shopProvider.notifier).saveShop(shop);

    if (mounted) {
      context.go('/billing');
    }
  }

  void _showError(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.red[700],
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 600;
    final isMediumPhone = screenHeight >= 600 && screenHeight < 700;

    if (l10n == null) {
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
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 60 : (isSmallPhone ? 20 : 24),
                  vertical: isSmallPhone ? 16 : (isMediumPhone ? 20 : 24),
                ),
                children: [
                  SizedBox(height: isSmallPhone ? 40 : 50),
                  
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          _buildHeaderSection(primaryColor),
                          const SizedBox(height: 32),
                          _buildForm(l10n, primaryColor),
                          const SizedBox(height: 40),
                          _buildContinueButton(l10n, primaryColor),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Back button - MUST BE LAST IN STACK TO BE ON TOP
              Positioned(
                top: 24,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor, size: 20),
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authProvider.notifier).logout();
                      await ref.read(shopProvider.notifier).clearShop();
                      if (context.mounted) {
                        router.go('/login');
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
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

  List<Widget> _buildBackgroundCircles(Color primaryColor) {
    return [
      Positioned(
        top: -100,
        right: -50,
        child: Container(
          width: 200,
          height: 200,
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
        bottom: -80,
        left: -80,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeaderSection(Color primaryColor) {
    const logoSize = 100.0;
    
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Setup Your Shop',
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Let\'s get your business ready',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(dynamic l10n, Color primaryColor) {
    const contentPadding = 18.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            _buildInputField(
              controller: _nameController,
              focusNode: _nameFocus,
              hint: 'Enter your shop name',
              label: l10n.translate('shop_name'),
              icon: Icons.store_outlined,
              primaryColor: primaryColor,
              contentPadding: contentPadding,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _ownerFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _ownerController,
              focusNode: _ownerFocus,
              hint: 'Enter owner name',
              label: l10n.translate('owner_name'),
              icon: Icons.person_outline,
              primaryColor: primaryColor,
              contentPadding: contentPadding,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _upiFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _upiController,
              focusNode: _upiFocus,
              hint: 'shop@upi',
              label: l10n.translate('upi_id'),
              icon: Icons.payments_outlined,
              primaryColor: primaryColor,
              contentPadding: contentPadding,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _addressFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildShopTypeDropdown(l10n, primaryColor, contentPadding),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _addressController,
              focusNode: _addressFocus,
              hint: 'Enter shop address',
              label: 'Address (Optional)',
              icon: Icons.location_on_outlined,
              primaryColor: primaryColor,
              maxLines: 2,
              contentPadding: contentPadding,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSave(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required String label,
    required IconData icon,
    required Color primaryColor,
    required double contentPadding,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFocused ? primaryColor : Colors.grey[500],
              ),
            ),
          ),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(
                icon,
                size: 22,
                color: isFocused ? primaryColor : Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: contentPadding),
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTypeDropdown(dynamic l10n, Color primaryColor, double contentPadding) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              l10n.translate('shop_type'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: contentPadding),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 22,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedShopType,
                      isExpanded: true,
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: primaryColor,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                      items: _shopTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedShopType = val);
                          HapticFeedback.lightImpact();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(dynamic l10n, Color primaryColor) {
    const buttonHeight = 56.0;
    const fontSize = 16.0;
    
    return ElevatedButton(
      onPressed: _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 0,
        shadowColor: primaryColor.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.translate('continue'),
            style: const TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}