import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../models/season.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PlayerStatsScreen extends StatefulWidget {
  final int userId;
  final String username;
  const PlayerStatsScreen({super.key, required this.userId, required this.username});
  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  final _api = ApiService(apiClient);
  Map<String, dynamic>? _stats;
  num? _rating;
  List<Match> _matches = [];
  bool _loading = true;
  int _leagueId = 1;
  List<Season> _seasons = [];
  int? _seasonId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final seasons = await _api.getSeasons(_leagueId);
      final stats = await _api.getPlayerStatistics(_leagueId, seasonId: _seasonId);
      final matches = await _api.getLeagueMatches(_leagueId);
      List<Map<String, dynamic>> ratings;
      try {
        ratings = await _api.getRatings(_leagueId);
      } catch (_) {
        ratings = [];
      }
      final my = stats.where((s) => s['user'] == widget.userId).toList();
      setState(() {
        _stats = my.isNotEmpty ? my.first : null;
        _rating = ratings.where((r) => r['user'] == widget.userId).map((r) => (r['rating'] ?? 0) as num).fold<num>(0, (a, b) => a);
        _matches = matches;
        _seasons = seasons;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  List<String> _recentForm() {
    final mine = _matches.where((m) =>
        m.status == 'VERIFIED' && (m.homeUserId == widget.userId || m.awayUserId == widget.userId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine.take(8).map((m) {
      final home = m.homeUserId == widget.userId;
      final gf = home ? (m.homeScore ?? 0) : (m.awayScore ?? 0);
      final ga = home ? (m.awayScore ?? 0) : (m.homeScore ?? 0);
      if (gf > ga) return 'W';
      if (gf < ga) return 'L';
      return 'D';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text(widget.username, style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_seasons.isNotEmpty) ...[
                _seasonPicker(),
                const SizedBox(height: 16),
              ],
              _headerCard(),
              const SizedBox(height: 16),
              _formCard(),
              const SizedBox(height: 16),
              _recordCard(),
              const SizedBox(height: 16),
              _goalsCard(),
              const SizedBox(height: 16),
              _streakCard(),
              const SizedBox(height: 16),
              _historyCard(),
            ]),
    );
  }

  Widget _seasonPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SEASON', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _seasons.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isAllTime = i == 0;
            final label = isAllTime ? 'All Time' : _seasons[i - 1].name;
            final id = isAllTime ? null : _seasons[i - 1].id;
            final selected = _seasonId == id;
            return ChoiceChip(
              label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white54)),
              selected: selected,
              onSelected: (_) { setState(() => _seasonId = id); _load(); },
              selectedColor: FCColors.surfaceLight,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            );
          },
        ),
      ),
    ]);
  }

  Widget _headerCard() {
    final s = _stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [FCColors.surface, FCColors.surfaceLight]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: FCColors.accent,
          child: Text(widget.username.isEmpty ? '?' : widget.username[0].toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(s != null
              ? '${s['wins'] ?? 0}W - ${s['draws'] ?? 0}D - ${s['losses'] ?? 0}L  •  ${s['points'] ?? 0} pts'
              : 'No stats yet',
              style: TextStyle(fontSize: 13, color: FCColors.white70)),
        ])),
        if (_rating != null && _rating! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text('RATING', style: TextStyle(fontSize: 9, color: FCColors.white50, letterSpacing: 1)),
              Text(_rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            ]),
          ),
      ]),
    );
  }

  Widget _formCard() {
    final form = _recentForm();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Text('RECENT FORM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(width: 12),
        if (form.isEmpty)
          Text('no matches', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3)))
        else
          ...form.map((f) {
            final color = f == 'W' ? Colors.green : f == 'L' ? Colors.red : Colors.grey;
            return Container(
              width: 26, height: 26,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
              child: Center(child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
            );
          }),
      ]),
    );
  }

  Widget _recordCard() {
    final s = _stats;
    return _tileCard('RECORD', [
      ('Played', s?['matches_played'] ?? 0),
      ('Wins', s?['wins'] ?? 0),
      ('Draws', s?['draws'] ?? 0),
      ('Losses', s?['losses'] ?? 0),
      ('Win Rate', s?['win_rate'] != null ? '${s!['win_rate']}' : '0%'),
    ]);
  }

  Widget _goalsCard() {
    final s = _stats;
    return _tileCard('GOALS', [
      ('Scored', s?['goals_scored'] ?? 0),
      ('Conceded', s?['goals_conceded'] ?? 0),
      ('GD', s?['goal_difference'] ?? 0),
      ('Clean Sheets', s?['clean_sheets'] ?? 0),
      ('Points', s?['points'] ?? 0),
    ]);
  }

  Widget _streakCard() {
    final s = _stats;
    return _tileCard('STREAKS', [
      ('Current Win Streak', s?['current_win_streak'] ?? 0),
      ('Best Win Streak', s?['best_win_streak'] ?? 0),
      ('Longest Unbeaten', s?['longest_unbeaten'] ?? 0),
      ('Ever Streak', s?['win_streak'] ?? 0),
    ]);
  }

  Widget _tileCard(String title, List<(String, Object)> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FCColors.white50, letterSpacing: 1)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: items.length > 4 ? 3 : items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: items.map((e) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.$2}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(e.$1, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: FCColors.white30)),
          ])).toList(),
        ),
      ]),
    );
  }

  Widget _historyCard() {
    final mine = _matches.where((m) =>
        m.status == 'VERIFIED' && (m.homeUserId == widget.userId || m.awayUserId == widget.userId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MATCH HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FCColors.white50, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (mine.isEmpty)
          Text('no matches', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3)))
        else
          ...mine.take(10).map((m) {
            final isHome = m.homeUserId == widget.userId;
            final gf = isHome ? (m.homeScore ?? 0) : (m.awayScore ?? 0);
            final ga = isHome ? (m.awayScore ?? 0) : (m.homeScore ?? 0);
            final color = gf > ga ? Colors.green : gf < ga ? Colors.red : Colors.grey;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Container(width: 2, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(child: Text('${m.homeUsername ?? '?'} vs ${m.awayUsername ?? '?'}',
                  style: const TextStyle(fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('$gf - $ga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 8),
                Text(m.createdAt.substring(0, 10), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
              ]),
            );
          }),
      ]),
    );
  }
}