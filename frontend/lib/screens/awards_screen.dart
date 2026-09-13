import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/award.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';

/// League awards, honouring the difference between a trophy the league
/// computed automatically and one an organizer awarded by hand.
///
/// Awards are derived from verified matches, so an empty list means nothing has
/// been settled yet — not that the feature is missing.
class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key});
  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  final _api = ApiService(apiClient);
  List<Map<String, dynamic>> _leagues = [];
  Map<String, dynamic>? _league;
  List<Award> _awards = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _leagueId => (_league?['id'] as int?) ?? 0;

  bool get _isManager {
    final role = _league?['my_role'] ?? _league?['role'];
    return role == 'LEAGUE_OWNER' || role == 'LEAGUE_ADMIN';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final leagues = await _api.getMyLeagues();
      final league = _league ?? (leagues.isNotEmpty ? leagues.first : null);
      final awards =
          league == null ? <Award>[] : await _api.getAwards(league['id'] as int);
      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _league = league;
        _awards = awards;
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

  Future<void> _compute() async {
    setState(() => _busy = true);
    try {
      final res = await _api.computeAwards(_leagueId);
      final created = res['count'] ?? res['created'] ?? 0;
      if (!mounted) return;
      _toast('Awards updated from verified results ($created).');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Could not compute awards: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? FCColors.red : FCColors.accentDark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Awards', style: TextStyle(color: Colors.white)),
        actions: [
          if (_isManager)
            IconButton(
              tooltip: 'Compute awards from verified results',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: _busy ? null : _compute,
            ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loading ? null : _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: FCColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: FCColors.red),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_leagues.length > 1) _leaguePicker(),
              if (_awards.isEmpty) _emptyState(),
              AdaptiveGrid(
                minItemWidth: 400,
                maxColumns: 3,
                children: _awards.map(_awardCard).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaguePicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _leagueId,
          isExpanded: true,
          dropdownColor: FCColors.surface,
          icon: const Icon(Icons.expand_more, color: FCColors.white50),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _leagues
              .map((l) => DropdownMenuItem<int>(
                    value: l['id'] as int,
                    child: Text(l['name'] ?? 'League'),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _league = _leagues.firstWhere((l) => l['id'] == id);
            });
            _load();
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(children: [
        const Icon(Icons.emoji_events_outlined,
            size: 64, color: FCColors.white15),
        const SizedBox(height: 16),
        const Text('No awards yet',
            style: TextStyle(color: FCColors.white70, fontSize: 16)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Awards are earned from verified results. Verify match results, or '
            'let an organizer award one by hand.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: FCColors.white30),
          ),
        ),
      ]),
    );
  }

  Widget _awardCard(Award award) {
    final isCustom = award.awardType == 'CUSTOM';
    final tint = isCustom ? FCColors.cyan : FCColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              Award.awardIcons[award.awardType] ?? '\u{1F396}',
              style: const TextStyle(fontSize: 26),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(award.displayName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(
                award.isTeamHolder
                    ? Icons.shield_outlined
                    : Icons.person_outline,
                size: 14,
                color: FCColors.accent,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  award.holderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      color: FCColors.accent,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            if (award.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(award.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: FCColors.white50)),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // An organizer's decision must not look like a computed one.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (award.isManual ? FCColors.cyan : FCColors.white30)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              award.isManual ? 'MANUAL' : 'AUTO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: award.isManual ? FCColors.cyan : FCColors.white50,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            award.awardedAt.length >= 10
                ? award.awardedAt.substring(0, 10)
                : award.awardedAt,
            style: TextStyle(fontSize: 11, color: FCColors.white30),
          ),
        ]),
      ]),
    );
  }
}
