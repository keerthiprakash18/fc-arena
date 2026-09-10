import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.groups,
      color: FCColors.accent,
      title: 'Leagues & Clubs',
      body: 'Create or join a league with a shareable invite code. Manage members, roles and certified results in one place.',
    ),
    (
      icon: Icons.verified_user,
      color: Color(0xFF16c79a),
      title: 'Verified Matches',
      body: 'Play matches, upload match evidence (screenshots/videos) and get AI-assisted verification with dispute support.',
    ),
    (
      icon: Icons.emoji_events,
      color: Color(0xFFf5a623),
      title: 'Tournaments & Brackets',
      body: 'Run knockout or league tournaments with auto-generated fixtures, brackets and automatic round advancement.',
    ),
    (
      icon: Icons.leaderboard,
      color: Color(0xFF7b2ff7),
      title: 'Ranks, Records & Awards',
      body: 'Track ratings, standings, head-to-head records, player stats, awards and category-based player pools.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [s.color, FCColors.surfaceLight]),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: s.color.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 4)],
                      ),
                      child: Icon(s.icon, size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text(s.title, textAlign: TextAlign.center, style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    Text(s.body, textAlign: TextAlign.center, style: TextStyle(
                      fontSize: 14, height: 1.5, color: FCColors.white50)),
                  ]),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _page ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _page ? FCColors.accent : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _page == _slides.length - 1
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FCColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_page == _slides.length - 1 ? 'GET STARTED' : 'NEXT',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}