import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'league_admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService(apiClient);
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _stats = [];
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = context.read<AuthProvider>().user;
      final leagues = await _api.getMyLeagues();
      int leagueId = 1;
      if (leagues.isNotEmpty) leagueId = leagues.first['id'];
      final ratings = await _api.getRatings(leagueId);
      final stats = await _api.getPlayerStatistics(leagueId);
      bool admin = false;
      try {
        final members = await _api.getLeagueMembers(leagueId);
        final me = members.where((m) => m['user'] == user?.id).toList();
        admin = me.isNotEmpty && ['LEAGUE_OWNER', 'LEAGUE_ADMIN'].contains(me.first['role']);
      } catch (_) {
        admin = false;
      }
      if (mounted) {
        setState(() { _ratings = ratings; _stats = stats; _isAdmin = admin; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _profileHeader(user),
                if (_isAdmin) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeagueAdminScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.admin_panel_settings, color: Colors.amber, size: 22),
                        SizedBox(width: 12),
                        Text('LEAGUE ADMIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 1)),
                        Spacer(),
                        Icon(Icons.chevron_right, color: Colors.amber),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_stats.isNotEmpty) ...[
                  const Text('STATISTICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  _statsGrid(),
                ],
                if (_ratings.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('RATING HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  _ratingCard(),
                ],
                if (_stats.isEmpty && _ratings.isEmpty)
                  Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Icon(Icons.person, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      Text('No stats yet — play some matches!', style: TextStyle(color: FCColors.white50)),
                    ]),
                  ),
              ],
            ),
    );
  }

  Widget _profileHeader(User? user) {
    final displayName = user?.displayName ?? 'Unknown';
    final photo = user?.profilePhoto;
    final email = user?.email ?? '';
    final isStaff = user?.isStaff ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FCColors.surface, FCColors.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: FCColors.accent,
          backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
          child: (photo != null && photo.isNotEmpty) ? null : Text(
            displayName[0].toUpperCase(),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        if ((user?.firstName != null && user!.firstName!.isNotEmpty) || (user?.lastName != null && user!.lastName!.isNotEmpty)) ...[
          const SizedBox(height: 2),
          Text([user.firstName, user.lastName].whereType<String>().where((s) => s.isNotEmpty).join(' '), style: TextStyle(fontSize: 13, color: FCColors.white70)),
        ],
        const SizedBox(height: 4),
        Text(email, style: TextStyle(fontSize: 14, color: FCColors.white50)),
        if (isStaff) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: const Text('ADMIN', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _statsGrid() {
    final s = _stats.first;
    final items = [
      ('MP', '${s['matches_played'] ?? 0}', Colors.blue),
      ('W', '${s['wins'] ?? 0}', Colors.green),
      ('D', '${s['draws'] ?? 0}', Colors.amber),
      ('L', '${s['losses'] ?? 0}', Colors.red),
      ('GF', '${s['goals_scored'] ?? 0}', Colors.cyan),
      ('GA', '${s['goals_conceded'] ?? 0}', Colors.redAccent),
      ('CS', '${s['clean_sheets'] ?? 0}', Colors.teal),
      ('Pts', '${s['points'] ?? 0}', Colors.purple),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.0),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(items[i].$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: items[i].$3.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(items[i].$2, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: items[i].$3)),
        ]),
      ),
    );
  }

  Widget _ratingCard() {
    final r = _ratings.first;
    final rating = (r['rating'] ?? 1000).toDouble();
    final peak = (r['peak_rating'] ?? 1000).toDouble();
    final matches = r['matches_rated'] ?? 0;
    final change = rating - 1000;
    final color = change >= 0 ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(rating.toStringAsFixed(0), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RATING', style: TextStyle(fontSize: 11, color: FCColors.white50)),
            Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _miniStat('Peak', peak.toStringAsFixed(0)),
          _miniStat('Matches', '$matches'),
          _miniStat('Win Rate', '${(_stats.isNotEmpty ? _stats.first['win_rate'] ?? 0 : 0)}%'),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: TextStyle(fontSize: 11, color: FCColors.white30)),
    ]);
  }
}