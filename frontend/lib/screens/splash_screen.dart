import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotateAnim = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    Widget next;
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      if (!mounted) return;

      if (!done) {
        next = const OnboardingScreen();
      } else {
        final auth = context.read<AuthProvider>();
        final autoLogin = await auth.tryAutoLogin();
        if (!mounted) return;
        next = autoLogin ? const MainShell() : const LoginScreen();
      }
    } catch (_) {
      if (!mounted) return;
      next = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => next,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FCGradients.hero),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      FCColors.accent.withValues(alpha:0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      FCColors.purple.withValues(alpha:0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: RotationTransition(
                        turns: _rotateAnim,
                        child: _buildLogo(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _slideAnim,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnim.value),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                colors: [FCColors.white, FCColors.accentBright],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'FC HARINA',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'FOOTBALL TOURNAMENT PLATFORM',
                            style: TextStyle(
                              fontSize: 12,
                              color: FCColors.accent.withValues(alpha:0.7),
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 64),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: FCColors.accent,
                        strokeWidth: 2.5,
                        backgroundColor: FCColors.white10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: FCGradients.accent,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: FCColors.accent.withValues(alpha:0.35),
            blurRadius: 50,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: FCColors.accent.withValues(alpha:0.1),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
      child: const Icon(
        Icons.sports_soccer,
        size: 60,
        color: Colors.white,
      ),
    );
  }
}
