import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/api.dart';
import '../models/tournament.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';
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
          backgroundColor: FCColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('New Tournament', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tournament name',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: format,
              dropdownColor: FCColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Format',
                prefixIcon: Icon(Icons.format_list_bulleted),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'KNOCKOUT', child: Text('Knockout')),
                DropdownMenuItem(value: 'LEAGUE', child: Text('League')),
                DropdownMenuItem(value: 'GROUP_KNOCKOUT', child: Text('Group + Knockout')),
              ],
              onChanged: (v) { if (v != null) setDState(() => format = v); },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCEL', style: TextStyle(color: FCColors.white40)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await _api.createTournament(_leagueId,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
          format: format,
          maxParticipants: maxP);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament created'), backgroundColor: FCColors.green),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: FCColors.red),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'REGISTRATION_OPEN':
        return FCColors.amber;
      case 'IN_PROGRESS':
        return FCColors.green;
      case 'COMPLETED':
        return FCColors.blue;
      case 'CANCELLED':
        return FCColors.red;
      case 'DRAFT':
        return FCColors.white40;
      default:
        return FCColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface.withValues(alpha: 0.95),
        title: const Text('Tournaments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: FCGradients.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FCColors.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _createTournament,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: FCColors.pitch),
          label: const Text('New Tournament', style: TextStyle(color: FCColors.pitch, fontWeight: FontWeight.w800)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? FCErrorRetry(message: _error!, onRetry: _load)
              : _tournaments.isEmpty
                  ? FCEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No Tournaments Yet',
                      subtitle: 'Create your first tournament to start organizing matches and tracking results.',
                      action: FCActionButton(
                        label: 'CREATE TOURNAMENT',
                        onPressed: _createTournament,
                        icon: Icons.add,
                        isFullWidth: false,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: FCColors.accent,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: ContentWidth(
                          child: AdaptiveGrid(
                            minItemWidth: 380,
                            maxColumns: 3,
                            children: [
                              for (final t in _tournaments) _tournamentCard(t),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _tournamentCard(Tournament t) {
    final color = _statusColor(t.status);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(leagueId: _leagueId, tournamentId: t.id),
      )),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderColor: color.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.emoji_events, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text('${t.formatLabel}  \u2022  ${t.code}',
                          style: TextStyle(fontSize: 12, color: FCColors.white40)),
                    ],
                  ),
                ),
                FCStatusBadge(
                  text: t.statusLabel,
                  color: color,
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, decoration: BoxDecoration(gradient: FCGradients.pitchLine)),
            const SizedBox(height: 14),
            Row(
              children: [
                _cardStat(Icons.people, '${t.participantCount}/${t.maxParticipants}'),
                const Spacer(),
                if (t.entryFee > 0) ...[
                  _cardStat(Icons.monetization_on, '\u20B9${t.entryFee.toStringAsFixed(0)}', color: FCColors.amber),
                ],
                if (t.prizePool > 0) ...[
                  const SizedBox(width: 12),
                  _cardStat(Icons.emoji_events, '\u20B9${t.prizePool.toStringAsFixed(0)}', color: FCColors.gold),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text('Created by ${t.createdBy}',
                style: TextStyle(fontSize: 11, color: FCColors.white30)),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? FCColors.white40),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: color ?? FCColors.white60, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
