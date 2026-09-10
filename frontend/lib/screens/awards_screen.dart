import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/award.dart';
import '../services/api_service.dart';

class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key});
  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  final _api = ApiService(apiClient);
  List<Award> _awards = [];
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
      final awards = await _api.getAwards(_leagueId);
      setState(() { _awards = awards; _loading = false; });
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
        title: const Text('Awards', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _awards.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text('No awards yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _awards.length,
                        itemBuilder: (_, i) => _awardCard(_awards[i]),
                      ),
                    ),
    );
  }

  Widget _awardCard(Award award) {
    final isCustom = award.awardType == 'CUSTOM';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCustom ? Colors.cyan.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: isCustom ? Colors.cyan.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(
            Award.awardIcons[award.awardType] ?? '🎖️',
            style: const TextStyle(fontSize: 26),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(award.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(award.username, style: const TextStyle(fontSize: 14, color: Color(0xFFe94560), fontWeight: FontWeight.w600)),
            if (award.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(award.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(award.source, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 4),
          Text(award.awardedAt.length >= 10 ? award.awardedAt.substring(0, 10) : award.awardedAt,
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
        ]),
      ]),
    );
  }
}