import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/tournament.dart';
import '../services/api_service.dart';
import 'tournament_detail_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});
  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final _api = ApiService(apiClient);
  List<Tournament> _tournaments = [];
  bool _loading = true;
  String? _error;
  int _leagueId = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final tournaments = await _api.getTournaments(_leagueId);
      setState(() { _tournaments = tournaments; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _createTournament() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String format = 'KNOCKOUT';
    int maxP = 16;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('New Tournament', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Tournament name', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: format,
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                label: const Text('Format', style: TextStyle(color: Colors.white54)),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'KNOCKOUT', child: Text('Knockout', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'LEAGUE', child: Text('League', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'GROUP_KNOCKOUT', child: Text('Group + Knockout', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) { if (v != null) setDState(() => format = v); },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Description', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560)), child: const Text('Create', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await _api.createTournament(_leagueId, name: nameCtrl.text.trim(), description: descCtrl.text.trim(), format: format, maxParticipants: maxP);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament created'), backgroundColor: Colors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Tournaments', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTournament,
        backgroundColor: const Color(0xFFe94560),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Tournament'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _tournaments.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('No tournaments yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tournaments.length,
                        itemBuilder: (_, i) => _tournamentCard(_tournaments[i]),
                      ),
                    ),
    );
  }

  Widget _tournamentCard(Tournament t) {
    final color = t.status == 'REGISTRATION_OPEN'
        ? Colors.amber
        : t.status == 'IN_PROGRESS' ? Colors.green
            : t.status == 'COMPLETED' ? Colors.blue : Colors.white54;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(leagueId: _leagueId, tournamentId: t.id),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.emoji_events, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text('${t.formatLabel} • ${t.code}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(t.statusLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.people, size: 14, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text('${t.participantCount}/${t.maxParticipants}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            const Spacer(),
            if (t.entryFee > 0) ...[
              Icon(Icons.monetization_on, size: 14, color: Colors.amber.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('₹${t.entryFee.toStringAsFixed(0)} entry', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            ],
            if (t.prizePool > 0) ...[
              const SizedBox(width: 12),
              Icon(Icons.emoji_events, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text('₹${t.prizePool.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600)),
            ],
          ]),
          const SizedBox(height: 8),
          Text('Created by ${t.createdBy}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }
}