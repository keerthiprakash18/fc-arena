import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard.dart';
import '../models/tournament.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';
import 'notifications_screen.dart';
import 'matches_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'disputes_screen.dart';
import 'seasons_screen.dart';
import 'tournaments_screen.dart';
import 'tournament_detail_screen.dart';
import 'teams_screen.dart';
import 'awards_screen.dart';
import 'records_screen.dart';
import 'profile_screen.dart';
import 'categories_screen.dart';
import 'head_to_head_screen.dart';
import 'match_schedule_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LeagueOverview? _overview;
  List<Tournament> _tournaments = [];
  bool _loading = true;
  bool _noLeagues = false;
  String? _error;
  int _unread = 0;
  int _leagueId = 0;
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
          _tournaments = [];
          _leagueId = 0;
        });
        return;
      }
      final leagueId = leagues.first['id'] as int;
      final overview = await _api.getLeagueOverview(leagueId);
      List<Tournament> tournaments = [];
      try {
        tournaments = await _api.getTournaments(leagueId);
      } catch (_) {
        // The pipeline can still render from the overview if tournaments fail.
      }
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _tournaments = tournaments;
        _leagueId = leagueId;
        _loading = false;
        _noLeagues = false;
        _error = null;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// The tournament the workflow pipeline focuses on: a live one first, else
  /// the first in the list.
  Tournament? get _featured {
    if (_tournaments.isEmpty) return null;
    final live = _tournaments.where((t) => t.status == 'IN_PROGRESS').toList();
    if (live.isNotEmpty) return live.first;
    return _tournaments.first;
  }

  /// Maps a tournament's state-machine status to the pipeline step (0-based)
  /// the organiser should be working on right.
  int _stepForStatus(String status) {
    switch (status) {
      case 'DRAFT': return 1;
      case 'REGISTRATION_OPEN': return 2;
      case 'REGISTRATION_CLOSED':
      case 'SEEDING':
      case 'FIXTURES_GENERATING': return 3;
      case 'READY':
      case 'IN_PROGRESS':
      case 'SUSPENDED': return 4;
      case 'COMPLETED': return 6;
      default: return 0; // CANCELLED / unknown
    }
  }

  Color _statusColor(String status) {
    if (status == 'REGISTRATION_OPEN') return FCColors.amber;
    if (status == 'IN_PROGRESS') return FCColors.accent;
    if (status == 'COMPLETED') return FCColors.blue;
    if (status == 'CANCELLED') return FCColors.red;
    if (status == 'DRAFT') return FCColors.white30;
    return FCColors.white50;
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
                  hintText: 'e.g. City Premier League',
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
        backgroundColor: FCColors.surface.withValues(alpha: 0.95),
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: FCGradients.accent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: FCColors.accent.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.sports_soccer, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(colors: [FCColors.white, FCColors.accentBright]).createShader(bounds);
            },
            child: const Text('FC HARINA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
          ),
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
                      const SizedBox(height: 16),
                      _buildPipeline(),
                      if (_tournaments.length > 1) ...[
                        const SizedBox(height: 16),
                        _buildTournamentsStrip(),
                      ],
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

  /// The centerpiece: a clear, connected tournament workflow. Each step is a
  /// real, tappable action that deep-links into the screen that performs it,
  /// and its state (done / next / upcoming) reflects the live tournament.
  Widget _buildPipeline() {
    final t = _featured;
    final current = t == null ? 0 : _stepForStatus(t.status);
    final labels = [
      'Create Tournament',
      'Manage Tournament',
      'Add Teams',
      'Generate Fixtures',
      'Upload Results',
      'Points Table',
      'Knockout / Bracket',
    ];
    final subs = [
      'Spin up a new competition',
      'Open & configure the draw',
      'Register the participants',
      'Auto-schedule every match',
      'Submit & verify the scores',
      'Standings update automatically',
      'Cup rounds decide the champion',
    ];
    final icons = [
      Icons.add_circle_outline,
      Icons.tune_outlined,
      Icons.group_add_outlined,
      Icons.sports_score_outlined,
      Icons.cloud_upload_outlined,
      Icons.table_chart_outlined,
      Icons.emoji_events_outlined,
    ];

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: FCGradients.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_tree_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Tournament Workflow',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              if (t != null) StatusBadge(text: t.statusLabel, color: _statusColor(t.status), small: true),
            ],
          ),
          const SizedBox(height: 10),
          if (t == null)
            Text('No tournament yet — create your first one to kick off the workflow.',
              style: TextStyle(fontSize: 13, color: FCColors.white50, height: 1.4))
          else
            Text('${t.name}  •  ${t.formatLabel}',
              style: TextStyle(fontSize: 13, color: FCColors.accent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const PitchDivider(),
          const SizedBox(height: 4),
          ...List.generate(labels.length, (i) => _pipelineRow(i, labels[i], subs[i], icons[i], t, current)),
          const SizedBox(height: 14),
          _pipelineCta(t, current),
        ],
      ),
    );
  }

  Widget _pipelineRow(int i, String label, String sub, IconData icon, Tournament? t, int current) {
    final done = i < current;
    final active = i == current;
    final color = done
        ? FCColors.accent
        : active
            ? FCColors.accentBright
            : FCColors.white30;

    void go() {
      Widget screen;
      if (i == 0) {
        screen = const TournamentsScreen();
      } else if (i == 4) {
        screen = const MatchesScreen();
      } else {
        screen = t == null
            ? const TournamentsScreen()
            : TournamentDetailScreen(leagueId: _leagueId, tournamentId: t.id);
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: go,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active
                      ? color.withValues(alpha: 0.15)
                      : FCColors.white05,
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Icon(done ? Icons.check_rounded : icon,
                  color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : done ? FCColors.white70 : FCColors.white30)),
                    const SizedBox(height: 1),
                    Text(sub,
                      style: TextStyle(fontSize: 11, color: FCColors.white30)),
                  ],
                ),
              ),
              if (active)
                StatusBadge(text: 'NEXT', color: FCColors.accentBright, small: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pipelineCta(Tournament? t, int current) {
    final primary = t == null;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          if (t == null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TournamentsScreen()));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TournamentDetailScreen(leagueId: _leagueId, tournamentId: t.id),
            ));
          }
        },
        icon: Icon(primary ? Icons.add : Icons.open_in_new, size: 18),
        label: Text(primary ? 'CREATE TOURNAMENT' : 'OPEN TOURNAMENT',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: FCColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// Quick switcher between the league's tournaments (only shown when there
  /// is more than one, so it never duplicates the pipeline above).
  Widget _buildTournamentsStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FCSectionHeader(title: 'YOUR TOURNAMENTS'),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tournaments.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final t = _tournaments[i];
              final isFeatured = _featured?.id == t.id;
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TournamentDetailScreen(leagueId: _leagueId, tournamentId: t.id),
                )),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFeatured ? FCColors.accent.withValues(alpha: 0.12) : FCColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFeatured ? FCColors.accent.withValues(alpha: 0.5) : FCColors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 6),
                      StatusBadge(text: t.statusLabel, color: _statusColor(t.status), small: true),
                      const SizedBox(height: 6),
                      Text('${t.participantCount}/${t.maxParticipants} teams',
                        style: TextStyle(fontSize: 11, color: FCColors.white30)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Shown when the signed-in account belongs to no league yet.
  Widget _buildNoLeaguesView() {
    return RefreshIndicator(
      onRefresh: _loadOverview,
      color: FCColors.accent,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: FCGradients.accent,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: FCColors.accent.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 6),
                ],
              ),
              child: const Icon(Icons.emoji_events, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(colors: [FCColors.white, FCColors.accentBright]).createShader(bounds);
            },
            child: const Text(
              'Welcome to FC Harina',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your own football league and invite players, or join an existing league with an invite code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.6, color: FCColors.white40),
          ),
          const SizedBox(height: 40),
          FCActionButton(
            label: 'CREATE A LEAGUE',
            onPressed: _showCreateLeagueDialog,
            icon: Icons.add_circle_outline,
          ),
          const SizedBox(height: 16),
          FCActionButton(
            label: 'JOIN WITH INVITE CODE',
            onPressed: _showJoinLeagueDialog,
            icon: Icons.vpn_key_outlined,
            isSecondary: true,
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
              Text(greeting, style: TextStyle(fontSize: 13, color: FCColors.white40, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(colors: [FCColors.white, FCColors.accentBright]).createShader(bounds);
                },
                child: Text(
                  user?.displayName ?? 'Player',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [FCColors.accent.withValues(alpha: 0.2), FCColors.purple.withValues(alpha: 0.15)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: FCColors.accent.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Center(
            child: Text(
              (user?.username ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FCColors.accent),
            ),
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
                    Text('Code: ${_overview!.leagueCode}', style: TextStyle(fontSize: 12, color: FCColors.accent.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TournamentsScreen())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FCColors.accent,
                  side: BorderSide(color: FCColors.accent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('TOURNAMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
      _Action(Icons.search, 'Search', const SearchScreen(), FCColors.accent),
      _Action(Icons.sports_soccer, 'Matches', const MatchesScreen(), FCColors.accent),
      _Action(Icons.shield_outlined, 'Teams', const TeamsScreen(), FCColors.blue),
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
    // A fixed four columns wastes a desktop window and crowds a phone, so the
    // count follows the form factor instead.
    final crossAxisCount = switch (formFactorOf(context)) {
      FormFactor.desktop => 8,
      FormFactor.tablet => 6,
      FormFactor.mobile => 4,
    };
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: actions.map((a) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => a.screen)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                a.color.withValues(alpha: 0.08),
                a.color.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: a.color.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(color: a.color.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: a.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(a.label, style: TextStyle(color: a.color.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
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
