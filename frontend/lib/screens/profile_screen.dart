import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_utils.dart';
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : CustomScrollView(
              slivers: [
                _buildAppBar(user),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isAdmin) ...[
                          _buildAdminCard(),
                          const SizedBox(height: 20),
                        ],
                        if (_stats.isNotEmpty) ...[
                          const FCSectionHeader(title: 'STATISTICS'),
                          const SizedBox(height: 12),
                          _buildStatsGrid(),
                        ],
                        if (_ratings.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const FCSectionHeader(title: 'RATING'),
                          const SizedBox(height: 12),
                          _buildRatingCard(),
                        ],
                        if (_stats.isEmpty && _ratings.isEmpty) ...[
                          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                          FCEmptyState(
                            icon: Icons.person_outline,
                            title: 'No Stats Yet',
                            subtitle: 'Play some matches to see your statistics and rating history here.',
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar(User? user) {
    final displayName = user?.displayName ?? 'Unknown';
    final photo = user?.profilePhoto;
    final email = user?.email ?? '';
    final isStaff = user?.isStaff ?? false;
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: FCColors.surface.withValues(alpha: 0.95),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: FCGradients.hero),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: FCGradients.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: FCColors.accent.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                    border: Border.all(color: FCColors.white20, width: 2),
                  ),
                  child: (photo != null && photo.isNotEmpty)
                      ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(fontSize: 14, color: FCColors.white60),
                  ),
                ],
                if (isStaff) ...[
                  const SizedBox(height: 10),
                  FCStatusBadge(
                    text: 'ADMIN',
                    color: FCColors.gold,
                    small: true,
                    icon: Icons.verified,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: FCColors.red),
          onPressed: () => context.read<AuthProvider>().logout(),
        ),
      ],
    );
  }

  Widget _buildAdminCard() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LeagueAdminScreen()),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: FCColors.gold.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FCColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings, color: FCColors.gold, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEAGUE ADMIN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: FCColors.gold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage league settings, members, and tournaments',
                    style: TextStyle(fontSize: 12, color: FCColors.white40),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FCColors.gold, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final s = _stats.first;
    final items = [
      ('Matches', '${s['matches_played'] ?? 0}', FCColors.blue, Icons.sports_soccer),
      ('Wins', '${s['wins'] ?? 0}', FCColors.green, Icons.emoji_events),
      ('Draws', '${s['draws'] ?? 0}', FCColors.amber, Icons.handshake),
      ('Losses', '${s['losses'] ?? 0}', FCColors.red, Icons.close),
      ('Goals', '${s['goals_scored'] ?? 0}', FCColors.cyan, Icons.sports),
      ('Conceded', '${s['goals_conceded'] ?? 0}', FCColors.redDark, Icons.shield),
      ('Clean Sheets', '${s['clean_sheets'] ?? 0}', FCColors.teal, Icons.lock),
      ('Points', '${s['points'] ?? 0}', FCColors.purple, Icons.star),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              items[i].$3.withValues(alpha: 0.08),
              items[i].$3.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: items[i].$3.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(items[i].$4, size: 18, color: items[i].$3.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Text(
              items[i].$2,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: items[i].$3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              items[i].$1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: items[i].$3.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    final r = _ratings.first;
    final rating = safeDouble(r['rating'], fallback: 1000);
    final peak = safeDouble(r['peak_rating'], fallback: 1000);
    final matches = r['matches_rated'] ?? 0;
    final change = rating - 1000;
    final color = change >= 0 ? FCColors.green : FCColors.red;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rating.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RATING',
                    style: TextStyle(fontSize: 12, color: FCColors.white40, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            decoration: BoxDecoration(gradient: FCGradients.pitchLine),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniStat('Peak Rating', peak.toStringAsFixed(0), FCColors.gold),
              _miniStat('Matches', '$matches', FCColors.accent),
              _miniStat('Win Rate', '${(_stats.isNotEmpty ? _stats.first['win_rate'] ?? 0 : 0)}%', FCColors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: FCColors.white40, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
