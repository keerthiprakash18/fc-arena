import 'package:flutter/material.dart';

import '../config/api.dart';
import '../models/team.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fc_animations.dart';
import 'team_detail_screen.dart';

/// Teams hub for the current league: a ranked standings table and a browsable
/// squad grid, both driven by the same API data.
///
/// Everything shown here comes from verified matches. A team with no results
/// shows a real zero state, never placeholder numbers.
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key, this.leagueId});

  /// Overrides the auto-detected league (used when pushed from a team screen).
  final int? leagueId;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService(apiClient);
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<Team> _teams = [];
  List<TeamStanding> _standings = [];
  bool _loading = true;
  String? _error;
  int _leagueId = 0;
  String _search = '';
  bool _canManage = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Always read the league list: it both supplies a default league id and
      // tells us the caller's role, which gates the create-team affordances.
      var leagueId = widget.leagueId ?? 0;
      final leagues = await _api.getMyLeagues();
      if (leagues.isEmpty) {
        setState(() { _loading = false; _teams = []; _standings = []; });
        return;
      }
      if (leagueId == 0) leagueId = leagues.first['id'] as int;
      final mine = leagues.firstWhere(
        (l) => l['id'] == leagueId,
        orElse: () => leagues.first,
      );
      _canManage = _isManager(mine);
      _leagueId = leagueId;

      // Fetch both views up front so switching tabs is instant.
      final teams = await _api.getTeams(leagueId, search: _search);
      List<TeamStanding> standings = [];
      try {
        standings = await _api.getTeamStandings(leagueId);
      } catch (_) {
        // Standings are derived; a failure here must not blank the team list.
      }
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _standings = standings;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// The league payload carries the caller's role as `my_role`; only owners and
  /// admins may create teams, so the UI hides those affordances for everyone
  /// else instead of letting them hit a 403.
  bool _isManager(Map<String, dynamic> league) {
    final role = league['my_role'] ?? league['role'];
    return role == 'LEAGUE_OWNER' || role == 'LEAGUE_ADMIN';
  }

  Future<void> _openCreateTeam() async {
    final nameCtrl = TextEditingController();
    final shortCtrl = TextEditingController();
    final gameCtrl = TextEditingController();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: FCColors.surface,
          title: const Text('Create a team', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Team name',
                  hintText: 'e.g. Blaze United',
                  prefixIcon: Icon(Icons.shield_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shortCtrl,
                maxLength: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Short name (optional)',
                  hintText: 'BLZ',
                  counterStyle: TextStyle(color: FCColors.white30, fontSize: 10),
                ),
              ),
              TextField(
                controller: gameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Game (optional)',
                  hintText: 'e.g. FC Mobile',
                  prefixIcon: Icon(Icons.sports_esports_outlined, size: 20),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: FCColors.white50)),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setDState(() => busy = true);
                      try {
                        await _api.createTeam(
                          _leagueId,
                          name: name,
                          shortName: shortCtrl.text.trim(),
                          game: gameCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        _toast('Team created');
                      } catch (e) {
                        setDState(() => busy = false);
                        if (ctx.mounted) _toast(_readable(e), isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: FCColors.accent),
              child: busy
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('CREATE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    shortCtrl.dispose();
    gameCtrl.dispose();
  }

  String _readable(Object e) {
    if (e is ApiException) {
      if (e.message.contains('already exists')) return 'A team with that name already exists.';
      if (e.statusCode == 403) return 'Only a league owner or admin can create teams.';
      return e.message;
    }
    return e.toString();
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? FCColors.red : FCColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Teams'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: FCColors.accent,
          labelColor: FCColors.accent,
          unselectedLabelColor: FCColors.white50,
          tabs: const [
            Tab(text: 'STANDINGS'),
            Tab(text: 'SQUADS'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: _canManage && !_loading
          ? FloatingActionButton.extended(
              onPressed: _openCreateTeam,
              backgroundColor: FCColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Team'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [_buildStandings(), _buildSquads()],
                ),
    );
  }

  // ── Standings ─────────────────────────────────────────────────────────────
  Widget _buildStandings() {
    if (_standings.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_outlined,
        title: 'No standings yet',
        subtitle: 'The league table appears once teams have played and verified '
            'matches. Create teams and generate fixtures to get started.',
        action: _canManage
            ? ElevatedButton.icon(
                onPressed: _openCreateTeam,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('CREATE A TEAM'),
              )
            : null,
      );
    }

    // Scale the metric bars against the best team in the table.
    final maxPoints = _standings.map((s) => s.statistics.points).fold<int>(1, (a, b) => b > a ? b : a);

    return RefreshIndicator(
      onRefresh: _load,
      color: FCColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          _tableHeader(),
          const SizedBox(height: 6),
          ..._standings.map((row) => _standingsRow(row, maxPoints)),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    const style = TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: FCColors.white30, letterSpacing: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: const [
          SizedBox(width: 26, child: Text('#', style: style)),
          SizedBox(width: 34),
          Expanded(child: Text('TEAM', style: style)),
          SizedBox(width: 26, child: Text('P', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 26, child: Text('W', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 26, child: Text('D', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 26, child: Text('L', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 32, child: Text('GD', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 34, child: Text('PTS', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _standingsRow(TeamStanding row, int maxPoints) {
    final s = row.statistics;
    final isTop = row.rank <= 3;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeamDetailScreen(leagueId: _leagueId, teamId: row.teamId),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FCColors.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTop ? row.rankColor.withValues(alpha: 0.35) : FCColors.white10,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${row.rank}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: row.rankColor),
                  ),
                ),
                TeamLogo(
                  logoUrl: row.logoUrl,
                  initials: row.shortName.isNotEmpty ? row.shortName.toUpperCase() : row.name,
                  size: 30,
                  radius: 8,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _cell('${s.matchesPlayed}'),
                _cell('${s.wins}', color: s.wins > 0 ? FCColors.accent : null),
                _cell('${s.draws}'),
                _cell('${s.losses}', color: s.losses > 0 ? FCColors.red : null),
                _cell(s.goalDifference > 0 ? '+${s.goalDifference}' : '${s.goalDifference}',
                    color: s.goalDifference > 0 ? FCColors.accent
                        : s.goalDifference < 0 ? FCColors.red : null),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${s.points}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
            if (s.hasPlayed) ...[
              const SizedBox(height: 8),
              MetricBar(fraction: maxPoints == 0 ? 0 : s.points / maxPoints, color: row.rankColor, height: 3),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {Color? color}) {
    return SizedBox(
      width: 26,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: color ?? FCColors.white50, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Squads ────────────────────────────────────────────────────────────────
  Widget _buildSquads() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search teams…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                        _load();
                      },
                    ),
            ),
            // Debounced so typing doesn't fire a request per keystroke.
            onChanged: (value) {
              setState(() => _search = value);
              _debounceReload();
            },
          ),
        ),
        Expanded(
          child: _teams.isEmpty
              ? EmptyState(
                  icon: Icons.shield_outlined,
                  title: _search.isEmpty ? 'No teams yet' : 'No teams match "$_search"',
                  subtitle: _search.isEmpty
                      ? 'Teams you create will appear here with their squad, form and statistics.'
                      : 'Try a different name, or clear the search to see every team.',
                  action: _search.isEmpty && _canManage
                      ? ElevatedButton.icon(
                          onPressed: _openCreateTeam,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('CREATE A TEAM'),
                        )
                      : null,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FCColors.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: _teams.length,
                    itemBuilder: (_, i) => _teamCard(_teams[i]),
                  ),
                ),
        ),
      ],
    );
  }

  int _debounceToken = 0;
  void _debounceReload() {
    final token = ++_debounceToken;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (token == _debounceToken && mounted) _load();
    });
  }

  Widget _teamCard(Team team) {
    final s = team.stats;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeamDetailScreen(leagueId: _leagueId, teamId: team.id),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FCColors.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FCColors.white10),
        ),
        child: Row(
          children: [
            TeamLogo(
              logoUrl: team.logoUrl,
              initials: team.initials,
              size: 46,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (team.game.isNotEmpty)
                        StatusBadge(text: team.game, color: FCColors.blue, small: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 13, color: FCColors.white30),
                      const SizedBox(width: 4),
                      Text('${team.memberCount} player${team.memberCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11.5, color: FCColors.white50)),
                      if (team.captainName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.star_outline, size: 13, color: FCColors.gold.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(team.captainName!,
                              style: TextStyle(fontSize: 11.5, color: FCColors.white50),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (s.hasPlayed)
                    Row(
                      children: [
                        Text('${s.points} pts',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: FCColors.accent)),
                        const SizedBox(width: 10),
                        Text('${s.wins}W ${s.draws}D ${s.losses}L',
                            style: TextStyle(fontSize: 11, color: FCColors.white30)),
                        const Spacer(),
                        FormStrip(form: s.form, size: 16),
                      ],
                    )
                  else
                    Text('No verified matches yet',
                        style: TextStyle(fontSize: 11, color: FCColors.white30)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: FCColors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}
