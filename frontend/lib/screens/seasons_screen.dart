import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/season.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SeasonsScreen extends StatefulWidget {
  const SeasonsScreen({super.key});
  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  final _api = ApiService(apiClient);
  List<Season> _seasons = [];
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
      final seasons = await _api.getSeasons(_leagueId);
      setState(() { _seasons = seasons; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _createSeason() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FCColors.surface,
        title: const Text('New Season', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'Season name', hintStyle: TextStyle(color: FCColors.white30)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'Description (optional)', hintStyle: TextStyle(color: FCColors.white30)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text('Create', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await _api.createSeason(_leagueId, name: nameCtrl.text.trim(), description: descCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Season created'), backgroundColor: Colors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Seasons', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSeason,
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New Season'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _seasons.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.wb_sunny_outlined, size: 64, color: FCColors.white15),
                        const SizedBox(height: 16),
                        Text('No seasons yet', style: TextStyle(color: FCColors.white50)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _seasons.length,
                        itemBuilder: (_, i) => _seasonCard(_seasons[i]),
                      ),
                    ),
    );
  }

  Widget _seasonCard(Season season) {
    final color = season.status == 'ACTIVE'
        ? Colors.green
        : season.status == 'COMPLETED' ? Colors.blue : Colors.white54;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(
            season.isCurrent ? Icons.wb_sunny : Icons.wb_sunny_outlined,
            color: color, size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(season.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              if (season.isCurrent) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('CURRENT', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text('${season.memberCount} members', style: TextStyle(fontSize: 12, color: FCColors.white50)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(season.statusLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}