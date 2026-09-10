import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/dispute.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dispute_detail_screen.dart';
import 'raise_dispute_screen.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});
  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<Dispute> _disputes = [];
  bool _loading = true;
  String? _error;
  final _api = ApiService(apiClient);
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
      final disputes = await _api.getDisputes(_leagueId);
      setState(() { _disputes = disputes; _loading = false; });
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
        title: const Text('Disputes', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _disputes.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.gavel, size: 64, color: FCColors.white15),
                        const SizedBox(height: 16),
                        Text('No disputes yet', style: TextStyle(color: FCColors.white50)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _disputes.length,
                        itemBuilder: (_, i) => _disputeCard(_disputes[i]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RaiseDisputeScreen()));
          _load();
        },
        backgroundColor: FCColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Raise Dispute'),
      ),
    );
  }

  Widget _disputeCard(Dispute dispute) {
    final color = dispute.isOpen ? Colors.orange : Colors.green;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DisputeDetailScreen(leagueId: _leagueId, disputeId: dispute.id),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FCColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Match #${dispute.matchId} â€” ${dispute.reasonLabel}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text(dispute.status.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(dispute.description, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: FCColors.white50)),
          const SizedBox(height: 8),
          Row(children: [
            Text('Raised by ${dispute.raisedByName ?? '?'}', style: TextStyle(fontSize: 12, color: FCColors.white30)),
            const Spacer(),
            Text('${dispute.comments.length} comments', style: TextStyle(fontSize: 12, color: FCColors.white30)),
          ]),
        ]),
      ),
    );
  }
}