import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/award.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _api = ApiService(apiClient);
  List<LeagueRecord> _records = [];
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
      final records = await _api.getRecords(_leagueId);
      setState(() { _records = records; _loading = false; });
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
        title: const Text('League Records', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _records.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.leaderboard, size: 64, color: FCColors.white15),
                        const SizedBox(height: 16),
                        Text('No records yet', style: TextStyle(color: FCColors.white50)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _records.length,
                        itemBuilder: (_, i) => _recordCard(_records[i]),
                      ),
                    ),
    );
  }

  Widget _recordCard(LeagueRecord record) {
    final icon = LeagueRecord.recordIcons[record.recordType] ?? Icons.star;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.amber, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.recordTypeDisplay, style: TextStyle(fontSize: 12, color: FCColors.white50)),
            const SizedBox(height: 2),
            Text(record.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(record.value.toStringAsFixed(1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          Text(record.achievedAt.length >= 10 ? record.achievedAt.substring(0, 10) : '',
            style: TextStyle(fontSize: 10, color: FCColors.white30)),
        ]),
      ]),
    );
  }
}