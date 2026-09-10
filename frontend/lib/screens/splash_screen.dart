import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => done ? const LoginScreen() : const OnboardingScreen(),
      ));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFe94560), Color(0xFF0f3460)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFFe94560).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
                ),
                child: const Icon(Icons.sports_esports, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('FC ARENA', style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 6,
              )),
              const SizedBox(height: 8),
              Text('Esports Platform', style: TextStyle(
                fontSize: 14, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 3,
              )),
              const SizedBox(height: 40),
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: const Color(0xFFe94560), strokeWidth: 2),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}