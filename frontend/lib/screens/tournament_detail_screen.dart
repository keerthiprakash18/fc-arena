import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../models/tournament.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'bracket_view.dart';

class TournamentDetailScreen extends StatefulWidget {
  final int leagueId;
  final int tournamentId;
  const TournamentDetailScreen({super.key, required this.leagueId, required this.tournamentId});
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final _api = ApiService(apiClient);
  Tournament? _tournament;
  List<TournamentParticipant> _participants = [];
  List<TournamentRound> _rounds = [];
  bool _loading = true;
  String? _error;
  bool _isRegistered = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _api.getTournament(widget.leagueId, widget.tournamentId);
      final p = await _api.getTournamentParticipants(widget.leagueId, widget.tournamentId);
      final r = await _api.getTournamentRounds(widget.leagueId, widget.tournamentId);
      if (!mounted) return;
      final me = context.read<AuthProvider>().user?.username;
      var isAdmin = false;
      try {
        final members = await _api.getLeagueMembers(widget.leagueId);
        isAdmin = members.any((m) => m['username'] == me &&
            ['LEAGUE_OWNER', 'LEAGUE_ADMIN', 'TOURNAMENT_ADMIN'].contains(m['role']));
      } catch (_) {}
      setState(() {
        _tournament = t;
        _participants = p;
        _rounds = r;
        _isRegistered = p.any((pp) => pp.username == me);
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _register() async {
    try {
      await _api.registerForTournament(widget.leagueId, widget.tournamentId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered!'), backgroundColor: Colors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateStatus() async {
    if (_tournament == null) return;
    final transitions = {
      'DRAFT': ['REGISTRATION_OPEN', 'CANCELLED'],
      'REGISTRATION_OPEN': ['REGISTRATION_CLOSED', 'CANCELLED'],
      'REGISTRATION_CLOSED': ['SEEDING', 'REGISTRATION_OPEN'],
      'SEEDING': ['FIXTURES_GENERATING'],
      'FIXTURES_GENERATING': ['READY'],
      'READY': ['IN_PROGRESS', 'CANCELLED'],
      'IN_PROGRESS': ['COMPLETED', 'SUSPENDED'],
      'SUSPENDED': ['IN_PROGRESS', 'CANCELLED'],
    };
    final allowed = transitions[_tournament!.status] ?? [];
    if (allowed.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FCColors.surface,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('Transition: ${_tournament!.statusLabel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        const Divider(color: Colors.white12),
        for (final s in allowed)
          ListTile(
            leading: const Icon(Icons.arrow_forward, color: Colors.white54, size: 18),
            title: Text(s.replaceAll('_', ' '), style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, s),
          ),
      ])),
    );
    if (selected == null) return;
    try {
      await _api.updateTournamentStatus(widget.leagueId, widget.tournamentId, selected);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status â†’ $selected'), backgroundColor: Colors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _generateFixtures() async {
    try {
      final res = await _api.generateTournamentFixtures(widget.leagueId, widget.tournamentId);
      final created = res['matches_created'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(created != null && created > 0
              ? 'Generated $created match(es) â€” tournament ready!'
              : 'Fixtures ready!'),
          backgroundColor: Colors.green));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text(_tournament?.name ?? 'Tournament', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  _infoCard(),
                  if (_tournament!.canRegister && !_isRegistered) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('REGISTER NOW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (_isRegistered) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text('You are registered', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_isAdmin &&
                      _rounds.isEmpty &&
                      ['REGISTRATION_CLOSED', 'SEEDING', 'FIXTURES_GENERATING'].contains(_tournament!.status)) ...[
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _generateFixtures,
                        icon: const Icon(Icons.sports_score),
                        label: const Text('GENERATE FIXTURES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FCColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(children: [
                    const Text('Participants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    TextButton(
                      onPressed: _updateStatus,
                      child: const Text('Change Status', style: TextStyle(color: Colors.amber)),
                    ),
                  ]),
                  if (_participants.isEmpty)
                    Text('No participants yet', style: TextStyle(color: FCColors.white30))
                  else
                    ..._participants.map((p) => _participantRow(p)),
                  if (_rounds.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    BracketView(leagueId: widget.leagueId, tournamentId: widget.tournamentId),
                    const SizedBox(height: 20),
                    const Text('Rounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    ..._rounds.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: FCColors.white05, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(r.isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: r.isCurrent ? Colors.green : Colors.white38, size: 18),
                        const SizedBox(width: 10),
                        Text('Round ${r.roundNumber}: ${r.name}', style: TextStyle(
                          color: Colors.white, fontWeight: r.isCurrent ? FontWeight.bold : FontWeight.normal)),
                        const Spacer(),
                        Text(r.roundType, style: TextStyle(fontSize: 12, color: FCColors.white30)),
                      ]),
                    )),
                  ],
                ]),
    );
  }

  Widget _infoCard() {
    final t = _tournament!;
    final color = t.status == 'REGISTRATION_OPEN' ? Colors.amber
        : t.status == 'IN_PROGRESS' ? Colors.green : Colors.white54;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(t.statusLabel, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Text('${t.formatLabel} â€¢ ${t.code}', style: TextStyle(fontSize: 14, color: FCColors.white50)),
        if (t.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.description, style: TextStyle(fontSize: 14, color: FCColors.white70)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          _stat(Icons.people, '${t.participantCount}/${t.maxParticipants} slots'),
          const SizedBox(width: 16),
          _stat(Icons.calendar_today, t.startDate != null ? t.startDate!.substring(0, 10) : 'TBD'),
        ]),
        if (t.entryFee > 0 || t.prizePool > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (t.entryFee > 0) _stat(Icons.monetization_on, 'Entry: â‚¹${t.entryFee.toStringAsFixed(0)}'),
            if (t.entryFee > 0 && t.prizePool > 0) const SizedBox(width: 16),
            if (t.prizePool > 0) _stat(Icons.emoji_events, 'Prize: â‚¹${t.prizePool.toStringAsFixed(0)}'),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 14, color: FCColors.white30),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: FCColors.white50)),
    ]);
  }

  Widget _participantRow(TournamentParticipant p) {
    final isActive = p.status == 'ACTIVE' || p.status == 'REGISTERED';
    final isElim = p.status == 'ELIMINATED';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: FCColors.white05, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.person, size: 18, color: isActive ? Colors.green : isElim ? Colors.red : Colors.white54),
        const SizedBox(width: 10),
        Text(p.username, style: TextStyle(
          color: isActive ? Colors.white : Colors.white54,
          fontWeight: p.seedNumber != null ? FontWeight.bold : FontWeight.normal,
        )),
        const Spacer(),
        if (p.seedNumber != null)
          Text('#${p.seedNumber}', style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(p.status, style: TextStyle(fontSize: 11, color: isActive ? Colors.green : Colors.white38)),
      ]),
    );
  }
}