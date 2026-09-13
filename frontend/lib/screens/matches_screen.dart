import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import '../widgets/responsive.dart';
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
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Matches', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadMatches),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
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
                      Text('No matches yet', style: TextStyle(color: FCColors.white50)),
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
                        style: ElevatedButton.styleFrom(backgroundColor: FCColors.accent, foregroundColor: Colors.white),
                      ),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadMatches,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        child: ContentWidth(
                          child: AdaptiveGrid(
                            minItemWidth: 400,
                            maxColumns: 3,
                            children: [
                              for (var i = 0; i < _matches.length; i++)
                                MatchCard(
                                  match: _matches[i],
                                  index: i,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MatchDetailScreen(
                                          matchId: _matches[i].id),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateMatchScreen()),
          );
          if (created == true) _loadMatches();
        },
        backgroundColor: FCColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Match'),
      ),
    );
  }
}
