import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../../core/localization/localization_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _selectedLanguage = 'en';
  bool _acceptedTerms = false;
  
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
    
    // Initialize language from current state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLang = ref.read(shopProvider).shop?.language ?? 'en';
      if (mounted) {
        setState(() => _selectedLanguage = currentLang);
      }
    });

    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!_validateInputs(name, email, password, confirmPassword)) return;

    if (!_acceptedTerms) {
      _showError('Please accept the Terms & Conditions');
      return;
    }

    HapticFeedback.mediumImpact();
    
    final authNotifier = ref.read(authProvider.notifier);
    final shopNotifier = ref.read(shopProvider.notifier);

    await shopNotifier.clearShop();
    
    try {
      await authNotifier.signUp(
        fullName: name,
        email: email,
        password: password,
        language: _selectedLanguage,
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception:', '').trim());
      }
    }
  }

  bool _validateInputs(String name, String email, String password, String confirm) {
    if (name.isEmpty) {
      _showError('Please enter your full name');
      return false;
    }
    if (name.length < 3) {
      _showError('Name must be at least 3 characters');
      return false;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showError('Please enter a valid email address');
      return false;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }
    if (password != confirm) {
      _showError('Passwords do not match');
      return false;
    }
    return true;
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
    final state = ref.watch(authProvider);
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
              
              // Main content - Using ListView for better scrolling
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 60 : (isSmallPhone ? 20 : 24),
                  vertical: isSmallPhone ? 16 : (isMediumPhone ? 20 : 24),
                ),
                children: [
                  SizedBox(height: isSmallPhone ? 40 : 50),
                  
                  // Animated content
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          _buildLogoSection(primaryColor),
                          const SizedBox(height: 32),
                          _buildWelcomeText(l10n, primaryColor),
                          const SizedBox(height: 48),
                          _buildForm(l10n, primaryColor),
                          const SizedBox(height: 24),
                          _buildLanguageSelector(l10n, primaryColor),
                          const SizedBox(height: 20),
                          _buildTermsCheckbox(primaryColor),
                          const SizedBox(height: 32),
                          _buildSignupButton(l10n, state, primaryColor),
                          const SizedBox(height: 16),
                          _buildLoginLink(l10n, state, primaryColor),
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.orange, size: 20),
                    onPressed: () => context.pop(),
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

  Widget _buildLogoSection(Color primaryColor) {
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Viyan Billing',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: primaryColor,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText(dynamic l10n, Color primaryColor) {
    return Column(
      children: [
        Text(
          l10n.translate('create_account'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34.0,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Get started with your business journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.0,
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
              hint: l10n.translate('full_name'),
              icon: Icons.person_outline,
              primaryColor: primaryColor,
              textInputAction: TextInputAction.next,
              contentPadding: contentPadding,
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _emailController,
              focusNode: _emailFocus,
              hint: l10n.translate('email'),
              icon: Icons.email_outlined,
              primaryColor: primaryColor,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              contentPadding: contentPadding,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              hint: l10n.translate('password'),
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: !_isPasswordVisible,
              onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              primaryColor: primaryColor,
              textInputAction: TextInputAction.next,
              contentPadding: contentPadding,
              onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
            ),
            const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
            _buildInputField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocus,
              hint: l10n.translate('confirm_password'),
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: !_isConfirmPasswordVisible,
              onToggleVisibility: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              primaryColor: primaryColor,
              textInputAction: TextInputAction.done,
              contentPadding: contentPadding,
              onSubmitted: (_) => _handleSignUp(),
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
    required IconData icon,
    required Color primaryColor,
    required double contentPadding,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.w500,
            color: Colors.grey[400],
          ),
          prefixIcon: Icon(
            icon,
            size: 22,
            color: isFocused ? primaryColor : Colors.grey[400],
          ),
          suffixIcon: isPassword && onToggleVisibility != null
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                  onPressed: onToggleVisibility,
                  splashRadius: 20,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: contentPadding),
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(dynamic l10n, Color primaryColor) {
    const chipPadding = 14.0;
    const fontSize = 13.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Preferred Language',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildLanguageChip(
                'EN',
                'English',
                _selectedLanguage == 'en',
                () {
                  setState(() => _selectedLanguage = 'en');
                  ref.read(shopProvider.notifier).updateLanguage('en');
                },
                primaryColor,
                chipPadding,
                fontSize,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildLanguageChip(
                'தமிழ்',
                'Tamil',
                _selectedLanguage == 'ta',
                () {
                  setState(() => _selectedLanguage = 'ta');
                  ref.read(shopProvider.notifier).updateLanguage('ta');
                },
                primaryColor,
                chipPadding,
                fontSize,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageChip(String code, String label, bool isSelected, VoidCallback onTap, 
      Color primaryColor, double padding, double fontSize) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: 1.2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check_circle, size: 14, color: Colors.white),
              ),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(Color primaryColor) {
    const fontSize = 12.0;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
            activeColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[600],
                height: 1.3,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton(dynamic l10n, dynamic state, Color primaryColor) {
    const buttonHeight = 56.0;
    const fontSize = 16.0;
    
    return ElevatedButton(
      onPressed: state.isLoading ? null : _handleSignUp,
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
      child: state.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.translate('create_account'),
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

  Widget _buildLoginLink(dynamic l10n, dynamic state, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13.0,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: state.isLoading ? null : () => context.pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              l10n.translate('login'),
              style: TextStyle(
                color: primaryColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}