import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import 'match_detail_screen.dart';
import 'create_match_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Match> _matches = [];
  bool _loading = true;
  String? _error;
  final _api = ApiService(apiClient);
  int _selectedLeagueId = 1;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _selectedLeagueId = leagues.first['id'];
      final matches = await _api.getLeagueMatches(_selectedLeagueId);
      setState(() { _matches = matches; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Matches', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadMatches),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadMatches, child: const Text('Retry')),
                ]))
              : _matches.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.sports_soccer, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      Text('No matches yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text('Create your first match to get started', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
                          );
                          if (created == true) _loadMatches();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Match'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white),
                      ),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadMatches,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _matches.length,
                        itemBuilder: (_, i) => _matchCard(_matches[i]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
          );
          if (created == true) _loadMatches();
        },
        backgroundColor: const Color(0xFFe94560),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Match'),
      ),
    );
  }

  Widget _matchCard(Match match) {
    final colors = {
      'VERIFIED': Colors.green, 'SCHEDULED': Colors.blue, 'AWAITING_RESULT': Colors.orange,
      'EVIDENCE_SUBMITTED': Colors.amber, 'ADMIN_REVIEW': Colors.purple, 'REJECTED': Colors.red,
    };
    final statusColor = colors[match.status] ?? Colors.grey;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: match.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(match.homeUsername ?? 'Home', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(match.awayUsername ?? 'Away', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(match.scoreDisplay, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(match.status.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (match.verifiedAt != null)
                  Text('Verified', style: TextStyle(fontSize: 11, color: Colors.green.withValues(alpha: 0.7))),
                if (match.tournamentId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.emoji_events, size: 14, color: Colors.amber.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}