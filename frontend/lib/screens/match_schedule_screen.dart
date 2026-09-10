import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import 'match_detail_screen.dart';

class MatchScheduleScreen extends StatefulWidget {
  const MatchScheduleScreen({super.key});
  @override
  State<MatchScheduleScreen> createState() => _MatchScheduleScreenState();
}

class _MatchScheduleScreenState extends State<MatchScheduleScreen> {
  final _api = ApiService(apiClient);
  List<Match> _matches = [];
  bool _loading = true;
  int _leagueId = 1;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final matches = await _api.getLeagueMatches(_leagueId);
      setState(() { _matches = matches; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  List<Match> get _filtered {
    if (_filter == 'ALL') return _matches;
    if (_filter == 'UPCOMING') return _matches.where((m) => m.status == 'SCHEDULED').toList();
    if (_filter == 'LIVE') return _matches.where((m) => !['VERIFIED', 'CANCELLED', 'SCHEDULED'].contains(m.status)).toList();
    if (_filter == 'COMPLETED') return _matches.where((m) => m.status == 'VERIFIED').toList();
    return _matches;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Match Schedule', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : Column(children: [
              _filterChips(),
              Expanded(child: _filtered.isEmpty
                  ? Center(child: Text('No matches', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _matchCard(_filtered[i]),
                      ),
                    )),
            ]),
    );
  }

  Widget _filterChips() {
    final filters = [('ALL', 'All'), ('UPCOMING', 'Upcoming'), ('LIVE', 'In Progress'), ('COMPLETED', 'Completed')];
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = _filter == filters[i].$1;
          return Center(
            child: ChoiceChip(
              label: Text(filters[i].$2, style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.white54)),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filters[i].$1),
              selectedColor: const Color(0xFFe94560),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _matchCard(Match match) {
    final color = match.status == 'VERIFIED' ? Colors.green
        : match.status == 'SCHEDULED' ? Colors.blue
            : match.status == 'CANCELLED' ? Colors.red
                : Colors.amber;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: match.id),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(match.homeUsername ?? '?', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(match.awayUsername ?? '?', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
          ])),
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(
                match.homeScore != null && match.awayScore != null
                    ? '${match.homeScore} - ${match.awayScore}'
                    : match.status.replaceAll('_', ' '),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(match.createdAt.substring(0, 10), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
          ]),
        ]),
      ),
    );
  }
}