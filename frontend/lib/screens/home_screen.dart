import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';
import 'notifications_screen.dart';
import 'matches_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'disputes_screen.dart';
import 'seasons_screen.dart';
import 'tournaments_screen.dart';
import 'awards_screen.dart';
import 'records_screen.dart';
import 'profile_screen.dart';
import 'categories_screen.dart';
import 'head_to_head_screen.dart';
import 'match_schedule_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LeagueOverview? _overview;
  bool _loading = true;
  String? _error;
  int _unread = 0;
  final _api = ApiService(apiClient);

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  Future<void> _loadOverview() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isEmpty) {
        setState(() { _loading = false; _error = 'No leagues found. Join a league first.'; });
        return;
      }
      final leagueId = leagues.first['id'];
      final overview = await _api.getLeagueOverview(leagueId);
      setState(() { _overview = overview; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Widget _notifBell() {
    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white),
          if (_unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFe94560),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1a1a2e), width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _loadUnread();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('FC ARENA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          _notifBell(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.person, size: 18), SizedBox(width: 8), Text('My Profile')]),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Logout')]),
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  onRefresh: _loadOverview,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildLeagueHeader(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildLeadersSection(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLeagueHeader() {
    if (_overview == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFe94560), Color(0xFF0f3460)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_overview!.leagueName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Code: ${_overview!.leagueCode}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_overview == null) return const SizedBox();
    final stats = [
      {'icon': Icons.people, 'label': 'Members', 'value': '${_overview!.membersCount}', 'color': Colors.blue},
      {'icon': Icons.emoji_events, 'label': 'Tournaments', 'value': '${_overview!.tournamentsCount}', 'color': Colors.amber},
      {'icon': Icons.sports_soccer, 'label': 'Matches', 'value': '${_overview!.matchesTotal}', 'color': Colors.green},
      {'icon': Icons.check_circle, 'label': 'Verified', 'value': '${_overview!.matchesVerified}', 'color': Colors.teal},
      {'icon': Icons.rate_review, 'label': 'Pending', 'value': '${_overview!.pendingReviews}', 'color': Colors.orange},
      {'icon': Icons.gavel, 'label': 'Disputes', 'value': '${_overview!.openDisputes}', 'color': Colors.red},
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: stats.map((s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (s['color'] as Color).withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
            const SizedBox(height: 8),
            Text(s['value'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: s['color'] as Color)),
            const SizedBox(height: 4),
            Text(s['label'] as String, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLeadersSection() {
    if (_overview?.leaders == null) return const SizedBox();
    final leaders = _overview!.leaders!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LEADERS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _leaderCard(Icons.emoji_events, 'Standings',
                  leaders['standings_leader']?['username'] ?? '-',
                  '${leaders['standings_leader']?['points'] ?? 0} pts', Colors.amber)),
              const SizedBox(width: 12),
              Expanded(child: _leaderCard(Icons.sports_soccer, 'Top Scorer',
                  leaders['top_scorer']?['username'] ?? '-',
                  '${leaders['top_scorer']?['goals'] ?? 0} goals', Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBadge(Icons.sports_soccer, 'Total Goals: ${_overview!.totalGoals}'),
              const SizedBox(width: 12),
              _statBadge(Icons.analytics, 'Avg: ${_overview!.avgGoalsPerMatch.toStringAsFixed(1)} / match'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leaderCard(IconData icon, String title, String name, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(title, style: TextStyle(fontSize: 11, color: color))]),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(value, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _statBadge(IconData icon, String text) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white54), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)))]),
    ));
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACTIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 12),
        Row(children: [
          _actionButton(Icons.sports_soccer, 'Matches', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MatchesScreen())), Colors.blue),
          const SizedBox(width: 12),
          _actionButton(Icons.leaderboard, 'Leaderboard', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())), Colors.amber),
          const SizedBox(width: 12),
          _actionButton(Icons.gavel, 'Disputes', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DisputesScreen())), Colors.red),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _actionButton(Icons.wb_sunny, 'Seasons', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeasonsScreen())), Colors.orange),
          const SizedBox(width: 12),
          _actionButton(Icons.emoji_events, 'Tournaments', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TournamentsScreen())), const Color(0xFFe94560)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _actionButton(Icons.workspace_premium, 'Awards', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AwardsScreen())), Colors.amber),
          const SizedBox(width: 12),
          _actionButton(Icons.leaderboard, 'Records', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordsScreen())), Colors.cyan),
          const SizedBox(width: 12),
          _actionButton(Icons.person, 'Profile', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())), Colors.purple),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _actionButton(Icons.category, 'Categories', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())), Colors.teal),
          const SizedBox(width: 12),
          _actionButton(Icons.balance, 'Head-to-Head', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HeadToHeadScreen())), const Color(0xFFe94560)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _actionButton(Icons.calendar_month, 'Schedule', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MatchScheduleScreen())), Colors.indigo),
          const SizedBox(width: 12),
          _actionButton(Icons.settings, 'Settings', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), Colors.grey),
        ]),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))]),
        ),
      ),
    );
  }
}