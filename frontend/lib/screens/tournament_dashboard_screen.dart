import 'package:flutter/material.dart';
import '../config/api.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fc_animations.dart';
import '../widgets/responsive.dart';
import 'match_detail_screen.dart';

/// Tournament-level dashboard with aggregate counts, leaders and recent fixtures.
class TournamentDashboardScreen extends StatefulWidget {
  final int leagueId;
  final int tournamentId;
  final String tournamentName;

  const TournamentDashboardScreen({
    super.key,
    required this.leagueId,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentDashboardScreen> createState() => _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState extends State<TournamentDashboardScreen> {
  final _api = ApiService(apiClient);
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getTournamentDashboard(widget.leagueId, widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text(widget.tournamentName, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FCColors.accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _statusHeader(),
                          const SizedBox(height: 16),
                          _progressCard(),
                          const SizedBox(height: 20),
                          const FCSectionHeader(title: 'PARTICIPANTS'),
                          const SizedBox(height: 12),
                          _participantGrid(),
                          const SizedBox(height: 20),
                          const FCSectionHeader(title: 'MATCHES'),
                          const SizedBox(height: 12),
                          _matchGrid(),
                          const SizedBox(height: 20),
                          _leaderCard(),
                          const SizedBox(height: 20),
                          const FCSectionHeader(title: 'RECENT FIXTURES'),
                          const SizedBox(height: 12),
                          _recentMatches(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: FCColors.red),
          const SizedBox(height: 12),
          Text('Failed to load dashboard', style: TextStyle(color: FCColors.white50, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: FCColors.white30, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: FCColors.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statusHeader() {
    final t = _data!['tournament'] as Map<String, dynamic>;
    final status = t['status'] as String? ?? 'DRAFT';
    final color = status == 'IN_PROGRESS'
        ? Colors.green
        : status == 'COMPLETED'
            ? FCColors.gold
            : Colors.amber;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: FCGradients.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['name'] as String? ?? widget.tournamentName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${(t['format'] as String? ?? '').replaceAll('_', ' ')} ${t['is_team_based'] == true ? '· Teams' : ''}',
                style: TextStyle(fontSize: 12, color: FCColors.white50),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status.replaceAll('_', ' '),
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _progressCard() {
    final perf = _data!['performance'] as Map<String, dynamic>;
    final progress = (perf['progress_percent'] as num?)?.toDouble() ?? 0.0;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tournament Progress', style: TextStyle(fontSize: 13, color: FCColors.white50, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ProgressRing(
            percent: progress,
            size: 72,
            strokeWidth: 7,
            child: Center(
              child: Text('${progress.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniText('Goals', '${perf['total_goals'] ?? 0}'),
              _miniText('Avg / Match', '${perf['avg_goals_per_match'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniText(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: FCColors.white30)),
      ],
    );
  }

  Widget _participantGrid() {
    final p = _data!['participants'] as Map<String, dynamic>;
    final items = [
      _statTile(Icons.people, 'Total', p['total'] ?? 0, FCColors.blue),
      _statTile(Icons.how_to_reg, 'Registered', p['registered'] ?? 0, FCColors.accent),
      _statTile(Icons.check_circle, 'Active', p['active'] ?? 0, Colors.green),
      _statTile(Icons.cancel, 'Eliminated', p['eliminated'] ?? 0, FCColors.red),
    ];
    return GridView.count(
      crossAxisCount: formFactorOf(context) == FormFactor.mobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items,
    );
  }

  Widget _matchGrid() {
    final m = _data!['matches'] as Map<String, dynamic>;
    final status = m['status_breakdown'] as Map<String, dynamic>? ?? {};
    final items = [
      _statTile(Icons.sports_soccer, 'Total', m['total'] ?? 0, FCColors.blue),
      _statTile(Icons.verified, 'Verified', m['verified'] ?? 0, Colors.green),
      _statTile(Icons.schedule, 'Scheduled', status['SCHEDULED'] ?? 0, FCColors.amber),
      _statTile(Icons.pending_actions, 'Pending', status['AWAITING_RESULT'] ?? 0, FCColors.white50),
    ];
    return GridView.count(
      crossAxisCount: formFactorOf(context) == FormFactor.mobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items,
    );
  }

  Widget _statTile(IconData icon, String label, dynamic value, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedCounter(
                  value: value is int ? value : 0,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: FCColors.white30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderCard() {
    final leader = (_data!['leaders'] as Map<String, dynamic>?)?['top_scorer'] as Map<String, dynamic>?;
    if (leader == null) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: FCColors.gold.withValues(alpha: 0.2),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FCColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.sports_soccer, color: FCColors.gold, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top Scorer', style: TextStyle(fontSize: 11, color: FCColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(leader['username'] as String? ?? '-',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
        Text('${leader['goals'] ?? 0}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FCColors.gold)),
      ]),
    );
  }

  Widget _recentMatches() {
    final matches = (_data!['recent_matches'] as List<dynamic>?) ?? [];
    if (matches.isEmpty) {
      return Text('No matches yet', style: TextStyle(color: FCColors.white30));
    }
    return Column(
      children: matches.map((m) {
        final home = m['home_display'] as String? ?? 'TBD';
        final away = m['away_display'] as String? ?? 'TBD';
        final homeScore = m['home_score'] as int?;
        final awayScore = m['away_score'] as int?;
        final hasScore = homeScore != null && awayScore != null;
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatchDetailScreen(matchId: m['id'] as int)),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: FCColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Text(home,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasScore ? FCColors.accent.withValues(alpha: 0.15) : FCColors.white05,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasScore ? '$homeScore - $awayScore' : 'vs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasScore ? FCColors.accent : FCColors.white30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(away,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
