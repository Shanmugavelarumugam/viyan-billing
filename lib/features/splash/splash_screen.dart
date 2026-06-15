import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/localization/localization_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    // We only delay if the router hasn't already redirected us
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final auth = ref.read(authProvider);
        if (!auth.isAuthenticated) {
          context.go('/login');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.45;
    final l10n = ref.watch(localizationProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9100), // Vibrant Orange
              Color(0xFFE65100), // Deep Orange
              Color(0xFFB71C1C), // Deep Red Hint
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Decorative Circles
            Positioned(
              top: -50,
              right: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -30,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),

            // Central Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Padding(
                          padding: EdgeInsets.only(top: 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                         Text(
                          (l10n?.translate('app_name') ?? 'Viyan Billing').toUpperCase(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                fontSize: size.width * 0.08,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.translate('fast_billing') ?? '5-Sec Billing / 5 நொடியில் பில்',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Loading Indicator
            const Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
