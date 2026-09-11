import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  bool _noLeagues = false;
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
        // A brand-new account has no leagues yet — offer create/join rather
        // than showing an error the user can never clear.
        setState(() {
          _loading = false;
          _noLeagues = true;
          _error = null;
          _overview = null;
        });
        return;
      }
      final leagueId = leagues.first['id'];
      final overview = await _api.getLeagueOverview(leagueId);
      setState(() {
        _overview = overview;
        _loading = false;
        _noLeagues = false;
        _error = null;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _showCreateLeagueDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FCColors.surface,
          title: const Text('Create a league', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'League name',
                  hintText: 'e.g. FC Arena Tamil',
                  prefixIcon: Icon(Icons.emoji_events_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text('CANCEL', style: TextStyle(color: FCColors.white50)),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      setDialogState(() => busy = true);
                      try {
                        await _api.createLeague(
                          name: name,
                          description: descController.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await _loadOverview();
                        if (mounted) _toast('League created');
                      } catch (e) {
                        setDialogState(() => busy = false);
                        if (dialogContext.mounted) {
                          _toast(_readableError(e), isError: true);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: FCColors.accent,
                foregroundColor: Colors.white,
              ),
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descController.dispose();
  }

  Future<void> _showJoinLeagueDialog() async {
    final codeController = TextEditingController();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FCColors.surface,
          title: const Text('Join a league', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the invite code you were given (looks like FC-7SXVJS).',
                style: TextStyle(fontSize: 12, color: FCColors.white50),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, letterSpacing: 2),
                decoration: const InputDecoration(
                  hintText: 'FC-XXXXXX',
                  prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text('CANCEL', style: TextStyle(color: FCColors.white50)),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;
                      setDialogState(() => busy = true);
                      try {
                        await _api.joinLeague(code);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await _loadOverview();
                        if (mounted) _toast('Joined league');
                      } catch (e) {
                        setDialogState(() => busy = false);
                        if (dialogContext.mounted) {
                          _toast(_readableError(e), isError: true);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: FCColors.accent,
                foregroundColor: Colors.white,
              ),
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('JOIN'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
  }

  /// Turn an ApiException into something a user can act on.
  String _readableError(Object error) {
    if (error is ApiException) {
      final msg = error.message;
      if (msg.contains('already a member')) return 'You are already in that league.';
      if (msg.contains('Invalid league code')) return 'That invite code is not valid.';
      return msg;
    }
    return error.toString();
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? FCColors.red : FCColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: FCGradients.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_soccer, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('FC ARENA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 17)),
        ]),
        actions: [
          _notifBell(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: FCColors.white70),
            onSelected: (v) {
              if (v == 'profile') Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (v == 'logout') _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline, size: 18, color: FCColors.white70), SizedBox(width: 10), Text('My Profile')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18, color: FCColors.red), SizedBox(width: 10), Text('Logout', style: TextStyle(color: FCColors.red))])),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _noLeagues
              ? _buildNoLeaguesView()
              : _error != null
                  ? ErrorRetry(message: _error!, onRetry: _loadOverview)
                  : RefreshIndicator(
                  onRefresh: _loadOverview,
                  color: FCColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildUserGreeting(),
                      const SizedBox(height: 16),
                      _buildLeagueCard(),
                      const SizedBox(height: 20),
                      const FCSectionHeader(title: 'STATISTICS'),
                      const SizedBox(height: 12),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      const FCSectionHeader(title: 'TOP PERFORMERS'),
                      const SizedBox(height: 12),
                      _buildLeadersSection(),
                      const SizedBox(height: 20),
                      const FCSectionHeader(title: 'QUICK ACCESS'),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                    ],
                  ),
                ),
    );
  }

  /// Shown when the signed-in account belongs to no league yet.
  Widget _buildNoLeaguesView() {
    return RefreshIndicator(
      onRefresh: _loadOverview,
      color: FCColors.accent,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          const SizedBox(height: 48),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: FCGradients.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.emoji_events, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to FC ARENA',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'You are not in a league yet. Create one and share its invite code with your players, or join a league using a code you were given.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: FCColors.white50),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _showCreateLeagueDialog,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('CREATE A LEAGUE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: FCColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _showJoinLeagueDialog,
              icon: const Icon(Icons.vpn_key_outlined, size: 20),
              label: const Text('JOIN WITH INVITE CODE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                foregroundColor: FCColors.accent,
                side: BorderSide(color: FCColors.accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGreeting() {
    final user = context.watch<AuthProvider>().user;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: TextStyle(fontSize: 13, color: FCColors.white30)),
              const SizedBox(height: 4),
              Text(
                user?.displayName ?? 'Player',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: FCColors.accent.withValues(alpha: 0.2),
          child: Text(
            (user?.username ?? 'U')[0].toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FCColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueCard() {
    if (_overview == null) return const SizedBox();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: FCGradients.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_overview!.leagueName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Code: ${_overview!.leagueCode}', style: TextStyle(fontSize: 12, color: FCColors.accent.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const PitchDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat(Icons.people, '${_overview!.membersCount}', 'Members'),
              _miniStat(Icons.emoji_events, '${_overview!.tournamentsCount}', 'Tournaments'),
              _miniStat(Icons.sports_soccer, '${_overview!.matchesTotal}', 'Matches'),
              _miniStat(Icons.check_circle, '${_overview!.matchesVerified}', 'Verified'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: FCColors.accent.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: FCColors.white30)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    if (_overview == null) return const SizedBox();
    final stats = [
      {'icon': Icons.rate_review, 'label': 'Pending', 'value': '${_overview!.pendingReviews}', 'color': FCColors.amber},
      {'icon': Icons.gavel, 'label': 'Disputes', 'value': '${_overview!.openDisputes}', 'color': FCColors.red},
      {'icon': Icons.sports_soccer, 'label': 'Goals', 'value': '${_overview!.totalGoals}', 'color': FCColors.accent},
      {'icon': Icons.analytics, 'label': 'Avg/Match', 'value': _overview!.avgGoalsPerMatch.toStringAsFixed(1), 'color': FCColors.blue},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: stats.map((s) => GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (s['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s['value'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: s['color'] as Color)),
                Text(s['label'] as String, style: TextStyle(fontSize: 11, color: FCColors.white30)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLeadersSection() {
    if (_overview?.leaders == null) return const SizedBox();
    final leaders = _overview!.leaders!;
    return Row(
      children: [
        Expanded(child: _leaderCard(Icons.emoji_events, 'Standings Leader',
            leaders['standings_leader']?['username'] ?? '-',
            '${leaders['standings_leader']?['points'] ?? 0} pts', FCColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: _leaderCard(Icons.sports_soccer, 'Top Scorer',
            leaders['top_scorer']?['username'] ?? '-',
            '${leaders['top_scorer']?['goals'] ?? 0} goals', FCColors.accent)),
      ],
    );
  }

  Widget _leaderCard(IconData icon, String title, String name, String value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, color: FCColors.white50)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _Action(Icons.sports_soccer, 'Matches', const MatchesScreen(), FCColors.accent),
      _Action(Icons.leaderboard, 'Rankings', const LeaderboardScreen(), FCColors.amber),
      _Action(Icons.emoji_events, 'Tournaments', const TournamentsScreen(), FCColors.gold),
      _Action(Icons.calendar_month, 'Schedule', const MatchScheduleScreen(), FCColors.blue),
      _Action(Icons.person, 'Profile', const ProfileScreen(), FCColors.purple),
      _Action(Icons.workspace_premium, 'Awards', const AwardsScreen(), FCColors.teal),
      _Action(Icons.category, 'Categories', const CategoriesScreen(), FCColors.cyan),
      _Action(Icons.balance, 'H2H', const HeadToHeadScreen(), FCColors.accent),
      _Action(Icons.gavel, 'Disputes', const DisputesScreen(), FCColors.red),
      _Action(Icons.wb_sunny, 'Seasons', const SeasonsScreen(), FCColors.amber),
      _Action(Icons.leaderboard, 'Records', const RecordsScreen(), FCColors.blue),
      _Action(Icons.settings, 'Settings', const SettingsScreen(), FCColors.white50),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: actions.map((a) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => a.screen)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: a.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(a.icon, color: a.color, size: 24),
              const SizedBox(height: 6),
              Text(a.label, style: TextStyle(color: a.color, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      )).toList(),
    );
  }

  void _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _notifBell() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: FCColors.white70, size: 24),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            _loadUnread();
          },
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: FCColors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FCColors.surface, width: 1.5),
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
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Widget screen;
  final Color color;
  const _Action(this.icon, this.label, this.screen, this.color);
}
