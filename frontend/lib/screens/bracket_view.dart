import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';

class BracketView extends StatefulWidget {
  final int leagueId;
  final int tournamentId;
  const BracketView({super.key, required this.leagueId, required this.tournamentId});
  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  final _api = ApiService(apiClient);
  List<Match> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final matches = await _api.getLeagueMatches(widget.leagueId);
      setState(() { _matches = matches; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: FCColors.accent)));
    }

    final completed = _matches.where((m) => m.status == 'VERIFIED').toList();
    final scheduled = _matches.where((m) => m.status == 'SCHEDULED' || m.status == 'AWAITING_RESULT').toList();
    final inProgress = _matches.where((m) => !['VERIFIED', 'CANCELLED', 'SCHEDULED'].contains(m.status)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_tree, color: FCColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('BRACKET (${_matches.length} matches)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
          const Spacer(),
          Text('${completed.length} completed', style: TextStyle(fontSize: 12, color: Colors.green.withValues(alpha: 0.7))),
        ]),
        const SizedBox(height: 16),
        if (inProgress.isNotEmpty) ...[
          _roundLabel('IN PROGRESS', Colors.amber),
          ...inProgress.map((m) => _matchTile(m, Colors.amber)),
          const SizedBox(height: 12),
        ],
        if (scheduled.isNotEmpty) ...[
          _roundLabel('SCHEDULED', Colors.blue),
          ...scheduled.map((m) => _matchTile(m, Colors.blue)),
          const SizedBox(height: 12),
        ],
        if (completed.isNotEmpty) ...[
          _roundLabel('COMPLETED', Colors.green),
          ...completed.map((m) => _matchTile(m, Colors.green)),
        ],
        if (_matches.isEmpty)
          Center(child: Text('No matches in this tournament yet', style: TextStyle(color: FCColors.white30))),
      ]),
    );
  }

  Widget _roundLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 3, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8), letterSpacing: 1)),
      ]),
    );
  }

  Widget _matchTile(Match match, Color color) {
    final homeWon = match.homeScore != null && match.awayScore != null && match.homeScore! > match.awayScore!;
    final awayWon = match.homeScore != null && match.awayScore != null && match.awayScore! > match.homeScore!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FCColors.white05,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color.withValues(alpha: 0.5), width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(match.homeUsername ?? '?',
            style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: homeWon ? FontWeight.bold : FontWeight.normal)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(
            match.homeScore != null && match.awayScore != null
                ? '${match.homeScore} - ${match.awayScore}'
                : 'vs',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(match.awayUsername ?? '?',
            style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: awayWon ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.end),
        ),
      ]),
    );
  }
}