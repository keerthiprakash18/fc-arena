import 'package:flutter/material.dart';
import '../config/api.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int userId;
  final String username;
  const PlayerProfileScreen({super.key, required this.userId, required this.username});
  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final _api = ApiService(apiClient);
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _rating;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leagues = await _api.getMyLeagues();
      int leagueId = 1;
      if (leagues.isNotEmpty) leagueId = leagues.first['id'];

      final stats = await _api.getPlayerStatistics(leagueId);
      final myStats = stats.firstWhere(
        (s) => s['user'] == widget.userId,
        orElse: () => {},
      );

      final ratings = await _api.getRatings(leagueId);
      final myRating = ratings.firstWhere(
        (r) => r['user'] == widget.userId,
        orElse: () => {},
      );

      setState(() {
        _stats = myStats.isNotEmpty ? myStats : null;
        _rating = myRating.isNotEmpty ? myRating : null;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text(widget.username, style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _avatar(),
                const SizedBox(height: 20),
                if (_rating != null && _rating!.isNotEmpty) _ratingCard(),
                if (_stats != null && _stats!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('STATISTICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  _statsGrid(),
                ],
                if (_stats == null && (_rating == null || _rating!.isEmpty))
                  Center(
                    child: Column(children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                      Text('No stats available for this player', style: TextStyle(color: FCColors.white50)),
                    ]),
                  ),
              ],
            ),
    );
  }

  Widget _avatar() {
    return Center(
      child: CircleAvatar(
        radius: 40,
        backgroundColor: FCColors.accent,
        child: Text(
          widget.username[0].toUpperCase(),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _ratingCard() {
    final rating = (_rating!['rating'] ?? 1000).toDouble();
    final peak = (_rating!['peak_rating'] ?? 1000).toDouble();
    final matches = _rating!['matches_rated'] ?? 0;
    final change = rating - 1000;
    final color = change >= 0 ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Column(children: [
          Text(rating.toStringAsFixed(0), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
          Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: color)),
        ]),
        Container(width: 1, height: 40, color: Colors.white12),
        Column(children: [
          Text(peak.toStringAsFixed(0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text('Peak', style: TextStyle(fontSize: 11, color: FCColors.white30)),
        ]),
        Container(width: 1, height: 40, color: Colors.white12),
        Column(children: [
          Text('$matches', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Matches', style: TextStyle(fontSize: 11, color: FCColors.white30)),
        ]),
      ]),
    );
  }

  Widget _statsGrid() {
    final s = _stats!;
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
}