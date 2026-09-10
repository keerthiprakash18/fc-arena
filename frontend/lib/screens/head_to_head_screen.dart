import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/leaderboard.dart';
import '../services/api_service.dart';
import 'player_stats_screen.dart';

class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});
  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  final _api = ApiService(apiClient);
  List<PlayerStanding> _players = [];
  int? _player1Id;
  int? _player2Id;
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _playersLoading = true;
  int _leagueId = 1;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final standings = await _api.getLeagueStandings(_leagueId);
      setState(() { _players = standings; _playersLoading = false; });
    } catch (e) {
      setState(() { _playersLoading = false; });
    }
  }

  Future<void> _compare() async {
    if (_player1Id == null || _player2Id == null) return;
    setState(() { _loading = true; _result = null; });
    try {
      final h2h = await _api.getHeadToHead(_leagueId, _player1Id!, _player2Id!);
      setState(() { _result = h2h; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Head to Head', style: TextStyle(color: Colors.white)),
      ),
      body: _playersLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _playerPicker('PLAYER 1', _player1Id, (v) => setState(() { _player1Id = v; _result = null; })),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(50)),
                    child: const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFe94560))),
                  ),
                ),
                const SizedBox(height: 16),
                _playerPicker('PLAYER 2', _player2Id, (v) => setState(() { _player2Id = v; _result = null; })),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_player1Id != null && _player2Id != null && _player1Id != _player2Id) ? _compare : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94560),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('COMPARE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _comparisonCard(),
                ],
              ],
            ),
    );
  }

  Widget _playerPicker(String label, int? selected, ValueChanged<int?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        initialValue: selected,
        dropdownColor: const Color(0xFF1a1a2e),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        isExpanded: true,
        hint: Text('Select player', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        items: _players.map((p) => DropdownMenuItem(
          value: p.userId,
          child: Text('${p.username} (${p.points} pts)', style: const TextStyle(color: Colors.white)),
        )).toList(),
        onChanged: onChanged,
      ),
    ]);
  }

  Widget _comparisonCard() {
    final r = _result!;
    final p1 = r['player1'] as Map<String, dynamic>? ?? {};
    final p2 = r['player2'] as Map<String, dynamic>? ?? {};
    final w1 = r['wins1'] as int? ?? 0;
    final w2 = r['wins2'] as int? ?? 0;
    final draws = r['draws'] as int? ?? 0;
    final matches = r['matches'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          Expanded(child: _playerStat(p1['username'] ?? '?', '$w1', Colors.green)),
          const Text('VS', style: TextStyle(fontSize: 14, color: Colors.white38)),
          Expanded(child: _playerStat(p2['username'] ?? '?', '$w2', Colors.blue)),
        ]),
        const SizedBox(height: 10),
        Text('Draws: $draws', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _player1Id == null ? null : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerStatsScreen(userId: _player1Id!, username: p1['username'] ?? '?')),
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: BorderSide(color: Colors.green.withValues(alpha: 0.5))),
              child: const Text('View Profile'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _player2Id == null ? null : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerStatsScreen(userId: _player2Id!, username: p2['username'] ?? '?')),
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: BorderSide(color: Colors.blue.withValues(alpha: 0.5))),
              child: const Text('View Profile'),
            ),
          ),
        ]),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('MATCHES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 8),
          ...matches.map((m) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Text('${m['home'] ?? '?'}', style: const TextStyle(fontSize: 13, color: Colors.white)),
              const SizedBox(width: 6),
              Text('${m['homeScore'] ?? '-'} - ${m['awayScore'] ?? '-'}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 6),
              Text('${m['away'] ?? '?'}', style: const TextStyle(fontSize: 13, color: Colors.white)),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _playerStat(String name, String wins, Color color) {
    return Column(children: [
      Text(wins, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
      Text(name, style: const TextStyle(fontSize: 13, color: Colors.white)),
      const Text('wins', style: TextStyle(fontSize: 11, color: Colors.white54)),
    ]);
  }
}