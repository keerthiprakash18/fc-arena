import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/award.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// League records, split into who holds each record now and who held it before.
///
/// Records come only from verified matches, so an empty list is the honest
/// answer for a league that has not played anything yet.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _api = ApiService(apiClient);
  List<Map<String, dynamic>> _leagues = [];
  Map<String, dynamic>? _league;
  List<LeagueRecord> _records = [];
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

  /// The record a league is currently setting, as opposed to an older holder
  /// kept for history.
  List<LeagueRecord> get _current =>
      _records.where((r) => r.isCurrent).toList();

  List<LeagueRecord> get _past =>
      _records.where((r) => !r.isCurrent).toList();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final leagues = await _api.getMyLeagues();
      final league = _league ??
          (leagues.isNotEmpty ? leagues.first : null);
      final records =
          league == null ? <LeagueRecord>[] : await _api.getRecords(league['id'] as int);
      if (!mounted) return;
      setState(() {
        _leagues = leagues;
        _league = league;
        _records = records;
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

  Future<void> _recompute() async {
    setState(() => _busy = true);
    try {
      final res = await _api.recomputeRecords(_leagueId);
      final count = res['count'] ?? 0;
      if (!mounted) return;
      _toast('Rebuilt $count record${count == 1 ? '' : 's'} from verified matches.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast('Could not rebuild records: $e', error: true);
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
        title: const Text('League Records',
            style: TextStyle(color: Colors.white)),
        actions: [
          if (_isManager)
            IconButton(
              tooltip: 'Rebuild from verified matches',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              onPressed: _busy ? null : _recompute,
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
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_leagues.length > 1) _leaguePicker(),
          if (_records.isEmpty) _emptyState() else ...[
            if (_current.isNotEmpty) ...[
              _sectionHeader('CURRENT HOLDERS', _current.length),
              ..._current.map((r) => _recordCard(r, current: true)),
            ],
            if (_past.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionHeader('PREVIOUS HOLDERS', _past.length),
              ..._past.map((r) => _recordCard(r, current: false)),
            ],
          ],
        ],
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

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FCColors.white50,
                letterSpacing: 1.6)),
        const SizedBox(width: 8),
        Text('($count)',
            style: const TextStyle(fontSize: 11, color: FCColors.white30)),
      ]),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(children: [
        const Icon(Icons.leaderboard_outlined, size: 64, color: FCColors.white15),
        const SizedBox(height: 16),
        const Text('No records yet',
            style: TextStyle(color: FCColors.white70, fontSize: 16)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Records are set by verified matches. Once a result is verified, '
            'the league leaders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: FCColors.white30),
          ),
        ),
      ]),
    );
  }

  Widget _recordCard(LeagueRecord record, {required bool current}) {
    final icon = LeagueRecord.recordIcons[record.recordType] ?? Icons.star;
    final tint = current ? FCColors.gold : FCColors.white30;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: current
                ? FCColors.gold.withValues(alpha: 0.25)
                : FCColors.white10),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.recordTypeDisplay,
                style: TextStyle(fontSize: 12, color: FCColors.white50)),
            const SizedBox(height: 3),
            Row(children: [
              // A club and a player are different things; say which one it is
              // rather than presenting a team as if it were a person.
              Icon(
                record.isTeamHolder
                    ? Icons.shield_outlined
                    : Icons.person_outline,
                size: 14,
                color: FCColors.accent,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  record.holderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: current ? Colors.white : FCColors.white70),
                ),
              ),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(record.value.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: tint)),
          Text(
            record.achievedAt.length >= 10
                ? record.achievedAt.substring(0, 10)
                : '',
            style: TextStyle(fontSize: 10, color: FCColors.white30),
          ),
        ]),
      ]),
    );
  }
}
