import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/leaderboard.dart';
import '../models/season.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'player_stats_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<PlayerStanding> _standings = [];
  List<LeaderboardEntry> _leaderboard = [];
  bool _loading = true;
  String? _error;
  final _api = ApiService(apiClient);
  String _selectedCategory = 'RATING';
  int _leagueId = 1;
  List<Season> _seasons = [];
  int? _seasonId;

  static const _categories = ['RATING', 'WINS', 'GOALS', 'WIN_RATE', 'GOAL_DIFF', 'MATCHES'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final seasons = await _api.getSeasons(_leagueId);
      final standings = await _api.getLeagueStandings(_leagueId, seasonId: _seasonId);
      final lb = await _api.getLeaderboard(_leagueId, category: _selectedCategory, seasonId: _seasonId);
      setState(() { _standings = standings; _leaderboard = lb; _seasons = seasons; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadData)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildStandingsTable(),
                      const SizedBox(height: 16),
                      if (_seasons.isNotEmpty) ...[
                        _buildSeasonPicker(),
                        const SizedBox(height: 16),
                      ],
                      _buildCategoryPicker(),
                      const SizedBox(height: 12),
                      _buildLeaderboardList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStandingsTable() {
    if (_standings.isEmpty) return const Center(child: Text('No standings yet', style: TextStyle(color: Colors.white54)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STANDINGS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _tableHeader(),
            ..._standings.asMap().entries.map((e) => _tableRow(e.key + 1, e.value)),
          ]),
        ),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
      child: const Row(children: [
        SizedBox(width: 30, child: Text('#', style: TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(flex: 2, child: Text('Player', style: TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(child: Text('P', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(child: Text('W', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(child: Text('D', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(child: Text('L', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(child: Text('GD', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(child: Text('Pts', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _tableRow(int rank, PlayerStanding s) {
    final isLeader = rank == 1;
    return GestureDetector(
      onTap: s.userId != null
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerStatsScreen(userId: s.userId!, username: s.username),
              ))
          : null,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: isLeader ? BoxDecoration(color: Colors.amber.withValues(alpha: 0.08)) : null,
      child: Row(children: [
        SizedBox(width: 30, child: Text('$rank', style: TextStyle(color: isLeader ? Colors.amber : Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text(s.username, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isLeader ? FontWeight.bold : FontWeight.normal))),
        Expanded(child: Text('${s.matchesPlayed}', style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center)),
        Expanded(child: Text('${s.wins}', style: const TextStyle(color: Colors.green, fontSize: 13), textAlign: TextAlign.center)),
        Expanded(child: Text('${s.draws}', style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center)),
        Expanded(child: Text('${s.losses}', style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center)),
        Expanded(child: Text('${s.goalDifference >= 0 ? '+' : ''}${s.goalDifference}', style: TextStyle(color: s.goalDifference >= 0 ? Colors.green : Colors.red, fontSize: 13), textAlign: TextAlign.center)),
        Expanded(child: Text('${s.points}', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      ]),
    ),
    );
  }

  Widget _buildSeasonPicker() {
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
              onSelected: (_) { setState(() => _seasonId = id); _loadData(); },
              selectedColor: FCColors.surfaceLight,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildCategoryPicker() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat.replaceAll('_', ' '), style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white54)),
            selected: selected,
            onSelected: (_) { setState(() => _selectedCategory = cat); _loadData(); },
            selectedColor: FCColors.accent,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          );
        },
      ),
    );
  }

  Widget _buildLeaderboardList() {
    if (_leaderboard.isEmpty) return const Center(child: Text('No leaderboard data', style: TextStyle(color: Colors.white54)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_selectedCategory.replaceAll('_', ' '), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 8),
        ..._leaderboard.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Text('${e.rank ?? '-'}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(e.username, style: const TextStyle(color: Colors.white, fontSize: 14))),
            Text(e.value != null ? e.value!.toStringAsFixed(1) : '-', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        )),
      ],
    );
  }
}