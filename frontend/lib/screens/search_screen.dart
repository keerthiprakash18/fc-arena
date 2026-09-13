import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api.dart';
import '../models/search.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fc_animations.dart';
import '../widgets/responsive.dart';
import 'match_detail_screen.dart';
import 'player_profile_screen.dart';
import 'team_detail_screen.dart';
import 'tournament_detail_screen.dart';

/// League-wide search across teams, tournaments, players and fixtures.
///
/// Typing is debounced, and responses are sequence-checked so a slow reply for
/// an earlier query can never overwrite the results of a later one.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final _api = ApiService(apiClient);
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;

  /// Incremented per request; a response is only applied if it is still current.
  int _requestSeq = 0;

  static const int _allLeaguesId = -1;

  List<Map<String, dynamic>> _leagues = [];
  int _leagueId = _allLeaguesId;
  SearchResults? _results;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadLeagues() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _leagueId = _allLeaguesId;
      });
      if (_controller.text.trim().isNotEmpty) _run(_controller.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      // Clearing the box should empty the list immediately, not after a delay.
      setState(() {
        _results = null;
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(_debounceDelay, () => _run(value));
  }

  Future<void> _run(String query) async {
    final seq = ++_requestSeq;
    setState(() => _searching = true);

    try {
      final results = _leagueId == _allLeaguesId
          ? await _api.searchGlobal(query)
          : await _api.searchLeague(_leagueId, query);
      // A newer keystroke has already been dispatched; drop this response.
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Search', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        _searchField(),
        if (_leagues.length > 1) _leaguePicker(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        onChanged: _onChanged,
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _debounce?.cancel();
          if (v.trim().isNotEmpty) _run(v);
        },
        decoration: InputDecoration(
          hintText: 'Search teams, tournaments, players, fixtures',
          hintStyle: TextStyle(color: FCColors.white30, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: FCColors.white50),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: FCColors.white50, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                    _focus.requestFocus();
                  },
                ),
          filled: true,
          fillColor: FCColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _leaguePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: FCColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _leagueId,
            isExpanded: true,
            dropdownColor: FCColors.surface,
            icon: const Icon(Icons.expand_more, color: FCColors.white50),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: [
              const DropdownMenuItem<int>(
                value: _allLeaguesId,
                child: Text('All Leagues'),
              ),
              ..._leagues.map((l) => DropdownMenuItem<int>(
                    value: l['id'] as int,
                    child: Text(l['name'] ?? 'League'),
                  )),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() => _leagueId = id);
              if (_controller.text.trim().isNotEmpty) _run(_controller.text);
            },
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _message(
        icon: Icons.error_outline,
        title: 'Search failed',
        subtitle: _error!,
        tint: FCColors.red,
      );
    }

    final results = _results;
    if (results == null) {
      return _message(
        icon: Icons.search,
        title: 'Search the league',
        subtitle: 'Find a team, a tournament, a player or a fixture by name.',
      );
    }

    if (results.isEmpty && !_searching) {
      return _message(
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Nothing in this league matches "${results.query}".',
      );
    }

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (results.teams.isNotEmpty)
                _section('TEAMS', Icons.shield_outlined, results.teams.length,
                    results.teams.map(_teamRow).toList()),
              if (results.tournaments.isNotEmpty)
                _section('TOURNAMENTS', Icons.emoji_events_outlined,
                    results.tournaments.length,
                    results.tournaments.map(_tournamentRow).toList()),
              if (results.players.isNotEmpty)
                _section('PLAYERS', Icons.person_outline, results.players.length,
                    results.players.map(_playerRow).toList()),
              if (results.matches.isNotEmpty)
                _section('FIXTURES', Icons.sports_soccer, results.matches.length,
                    results.matches.map(_matchRow).toList()),
            ],
          ),
        ),
      ),
      // A thin bar rather than a spinner over the list, so results stay legible
      // while a new query is in flight.
      if (_searching)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: FCColors.accent,
            backgroundColor: Colors.transparent,
          ),
        ),
    ]);
  }

  Widget _section(String label, IconData icon, int count, List<Widget> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Icon(icon, size: 14, color: FCColors.accent),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: FCColors.white50,
                  letterSpacing: 1.4)),
          const SizedBox(width: 6),
          Text('($count)',
              style: const TextStyle(fontSize: 11, color: FCColors.white30)),
        ]),
      ),
      AdaptiveGrid(
        minItemWidth: 380,
        maxColumns: 3,
        children: rows,
      ),
    ]);
  }

  Widget _teamRow(SearchTeam team) {
    return _tile(
      leading: TeamLogo(logoUrl: team.logo, initials: _initials(team.name), size: 38),
      title: team.name,
      subtitle: team.game.isNotEmpty ? team.game : 'Team',
      onTap: () => _open(
          TeamDetailScreen(leagueId: _leagueId, teamId: team.id)),
    );
  }

  Widget _tournamentRow(SearchTournament t) {
    return _tile(
      leading: _iconBox(Icons.emoji_events, FCColors.gold),
      title: t.name,
      subtitle: '${t.format.replaceAll('_', ' ')}  ·  ${t.statusLabel}'
          '${t.code.isNotEmpty ? '  ·  ${t.code}' : ''}',
      onTap: () => _open(TournamentDetailScreen(
          leagueId: _leagueId, tournamentId: t.id)),
    );
  }

  Widget _playerRow(SearchPlayer p) {
    return _tile(
      leading: _iconBox(Icons.person, FCColors.accent),
      title: p.displayName,
      subtitle: p.displayName == p.username ? 'Player' : '@${p.username}',
      onTap: () => _open(
          PlayerProfileScreen(userId: p.id, username: p.username)),
    );
  }

  Widget _matchRow(SearchMatch m) {
    return _tile(
      leading: _iconBox(
        Icons.sports_soccer,
        m.hasScore ? FCColors.accent : FCColors.blue,
      ),
      title: '${m.homeDisplay}  ${m.scoreLabel}  ${m.awayDisplay}',
      subtitle: [
        if (m.roundName != null) m.roundName!,
        m.status.replaceAll('_', ' '),
      ].join('  ·  '),
      onTap: () => _open(MatchDetailScreen(matchId: m.id)),
    );
  }

  Widget _tile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FCColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: FCColors.white50)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: FCColors.white30),
        ]),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? tint,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: tint ?? FCColors.white15),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: FCColors.white30)),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.length >= 2
          ? words.first.substring(0, 2).toUpperCase()
          : words.first.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}
