import 'package:flutter/material.dart';
import 'dart:async';
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
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeIn)));
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.elasticOut)));
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.7, curve: Curves.easeOut)));
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    Widget next;
    try {
      await Future.delayed(const Duration(seconds: 2));
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
      MaterialPageRoute(builder: (_) => next),
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
        decoration: const BoxDecoration(gradient: FCGradients.pitch),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: FCGradients.accent,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: FCColors.accent.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sports_soccer, size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'FC ARENA',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _slideAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: Opacity(
                          opacity: _slideAnim.value == 30 ? 0 : 1,
                          child: Text(
                            'FOOTBALL TOURNAMENT PLATFORM',
                            style: TextStyle(
                              fontSize: 11,
                              color: FCColors.accent.withValues(alpha: 0.8),
                              letterSpacing: 4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 28,
                    height: 28,
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
        ),
      ),
    );
  }
}
