import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../widgets/match_card.dart';
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
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Match Schedule', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : Column(children: [
              _filterChips(),
              Expanded(child: _filtered.isEmpty
                  ? Center(child: Text('No matches', style: TextStyle(color: FCColors.white30)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => MatchCard(
                          match: _filtered[i],
                          index: i,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MatchDetailScreen(matchId: _filtered[i].id),
                            ),
                          ),
                        ),
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
              selectedColor: FCColors.accent,
              backgroundColor: FCColors.white05,
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }
}
