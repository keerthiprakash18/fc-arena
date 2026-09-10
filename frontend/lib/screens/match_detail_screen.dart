import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import 'evidence_viewer_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  const MatchDetailScreen({super.key, required this.matchId});
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Match? _match;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  bool _actionInProgress = false;
  final _api = ApiService(apiClient);
  final _picker = ImagePicker();
  int _leagueId = 1;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      final match = await _api.getMatch(_leagueId, widget.matchId);
      final stats = await _api.getMatchStats(_leagueId, widget.matchId);
      final events = await _api.getMatchEvents(_leagueId, widget.matchId);
      setState(() { _match = match; _stats = stats; _events = events; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _submitResult() async {
    if (_match == null) return;
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Submit Result', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_match!.homeUsername} vs ${_match!.awayUsername}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: homeCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Home Score', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                style: const TextStyle(color: Colors.white))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('-', style: TextStyle(color: Colors.white, fontSize: 24))),
            Expanded(child: TextField(controller: awayCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Away Score', labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                style: const TextStyle(color: Colors.white))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560)),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final homeScore = int.tryParse(homeCtrl.text);
    final awayScore = int.tryParse(awayCtrl.text);
    if (homeScore == null || awayScore == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid scores')));
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await _api.submitResult(_leagueId, widget.matchId, homeScore: homeScore, awayScore: awayScore);
      await _loadMatch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _actionInProgress = false);
  }

  void _viewEvidence() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EvidenceViewerView(leagueId: _leagueId, matchId: widget.matchId),
    ));
  }

  Future<void> _uploadEvidence() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
    if (picked == null) return;
    setState(() => _actionInProgress = true);
    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      await _api.uploadEvidence(
        _leagueId, widget.matchId,
        filePath: picked.path,
        fileName: picked.name,
        fileSize: bytes.length,
        fileType: 'image/png',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evidence uploaded!'), backgroundColor: Colors.green));
      await _loadMatch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    }
    setState(() => _actionInProgress = false);
  }

  Future<void> _startMatch() async {
    setState(() => _actionInProgress = true);
    try {
      await _api.updateMatchStatus(_leagueId, widget.matchId, 'AWAITING_RESULT');
      await _loadMatch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _actionInProgress = false);
  }

  Future<void> _triggerVerification() async {
    setState(() => _actionInProgress = true);
    try {
      final task = await _api.triggerVerification(_leagueId, widget.matchId);
      if (mounted) {
        final msg = task.status == 'AI_VERIFIED'
            ? 'AI Auto-Verified! Score confirmed.'
            : 'Verification submitted — Status: ${task.status}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: task.status == 'AI_VERIFIED' ? Colors.green : Colors.orange,
        ));
      }
      await _loadMatch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _actionInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: const Color(0xFF0f0f23),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFe94560))));
    }
    if (_error != null || _match == null) {
      return Scaffold(backgroundColor: const Color(0xFF0f0f23),
        body: Center(child: Text(_error ?? 'Match not found', style: const TextStyle(color: Colors.white70))));
    }
    final match = _match!;
    final statusColors = {
      'VERIFIED': Colors.green, 'SCHEDULED': Colors.blue, 'AWAITING_RESULT': Colors.orange,
      'EVIDENCE_SUBMITTED': Colors.amber, 'ADMIN_REVIEW': Colors.purple,
    };
    final color = statusColors[match.status] ?? Colors.grey;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text('Match #${match.id}', style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), const Color(0xFF1a1a2e)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text(match.homeUsername ?? 'Home', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Text(match.scoreDisplay, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(match.status.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Text(match.awayUsername ?? 'Away', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 24),
          if (_actionInProgress) const Center(child: CircularProgressIndicator(color: Color(0xFFe94560))),
          if (!_actionInProgress) ...[
            if (match.status == 'SCHEDULED')
              _actionButton('Start Match', Icons.play_arrow, Colors.teal, _startMatch),
            if (match.canSubmitResult)
              _actionButton('Submit Result', Icons.edit, Colors.blue, _submitResult),
            if (match.canUploadEvidence)
              _actionButton('Upload Evidence', Icons.camera_alt, Colors.orange, _uploadEvidence),
            if (match.status == 'EVIDENCE_SUBMITTED')
              _actionButton('Trigger AI Verification', Icons.smart_toy, Colors.purple, _triggerVerification),
            _actionButton('View Evidence', Icons.folder_open, Colors.indigo, _viewEvidence),
          ],
          const SizedBox(height: 16),
          _infoRow('Match ID', '${match.id}'),
          _infoRow('Created', match.createdAt),
          if (match.verifiedAt != null) _infoRow('Verified', match.verifiedAt!),
          if (_stats.isNotEmpty) ...[
            const SizedBox(height: 20),
            _statsCard(),
          ],
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 20),
            _eventsTimeline(),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity, height: 48,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
      ]),
    );
  }

  Widget _eventsTimeline() {
    final eventIcons = {
      'GOAL': (Icons.sports_soccer, Colors.green),
      'OWN_GOAL': (Icons.sports_soccer, Colors.orange),
      'YELLOW_CARD': (Icons.square, Colors.amber),
      'RED_CARD': (Icons.square, Colors.red),
      'ASSIST': (Icons.handshake, Colors.blue),
      'SAVE': (Icons.shield, Colors.teal),
      'PENALTY_SCORED': (Icons.sports_soccer, Colors.green),
      'PENALTY_MISSED': (Icons.close, Colors.red),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('MATCH EVENTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
          const Spacer(),
          GestureDetector(
            onTap: _addEvent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text('Add Event', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ..._events.map((e) {
          final iconData = eventIcons[e['event_type']] ?? (Icons.circle, Colors.white54);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: iconData.$2.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(iconData.$1, color: iconData.$2, size: 16),
              ),
              const SizedBox(width: 10),
              Text("${e['minute']}'", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['event_type_display'] ?? e['event_type'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white)),
                Text(e['username'] ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Future<void> _addEvent() async {
    if (_match == null) return;
    final minuteCtrl = TextEditingController(text: '0');
    String eventType = 'GOAL';
    int? playerId;
    final eventTypes = [
      ('GOAL', 'Goal'), ('OWN_GOAL', 'Own Goal'), ('YELLOW_CARD', 'Yellow Card'),
      ('RED_CARD', 'Red Card'), ('ASSIST', 'Assist'), ('SAVE', 'Save'),
      ('PENALTY_SCORED', 'Penalty Scored'), ('PENALTY_MISSED', 'Penalty Missed'),
    ];

    final members = await _api.getLeagueMembers(_leagueId);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Add Event', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: minuteCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Minute", labelStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: eventType,
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Event Type', labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.08)),
              isExpanded: true,
              items: eventTypes.map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) { if (v != null) setDState(() => eventType = v); },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: playerId,
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Player', labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: Colors.white.withValues(alpha: 0.08)),
              isExpanded: true,
              hint: Text('Select player', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              items: members.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['username'] ?? '', style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setDState(() => playerId = v),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (confirmed != true || playerId == null) return;
    try {
      await _api.addMatchEvent(_leagueId, widget.matchId,
        eventType: eventType, minute: int.tryParse(minuteCtrl.text) ?? 0, playerId: playerId!);
      _loadMatch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MATCH STATS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 12),
        _statBar('Possession', _stats['home_possession'], _stats['away_possession'], '%'),
        _statBar('Shots', _stats['home_shots'], _stats['away_shots'], ''),
        _statBar('Shots on Target', _stats['home_shots_on_target'], _stats['away_shots_on_target'], ''),
        _statBar('Pass Accuracy', _stats['home_pass_accuracy'], _stats['away_pass_accuracy'], '%'),
        _statBar('Tackles', _stats['home_tackles'], _stats['away_tackles'], ''),
        _statBar('Corners', _stats['home_corners'], _stats['away_corners'], ''),
        _statBar('Fouls', _stats['home_fouls'], _stats['away_fouls'], ''),
        if (_stats['ai_confidence'] != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.smart_toy, size: 14, color: Colors.purple.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text('AI Confidence: ${_stats['ai_confidence']}%', style: TextStyle(fontSize: 12, color: Colors.purple.withValues(alpha: 0.6))),
          ]),
        ],
      ]),
    );
  }

  Widget _statBar(String label, dynamic home, dynamic away, String suffix) {
    if (home == null && away == null) return const SizedBox.shrink();
    final h = (home ?? 0).toDouble();
    final a = (away ?? 0).toDouble();
    final total = h + a;
    final hPct = total > 0 ? h / total : 0.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 30, child: Text('${h.toInt()}$suffix', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue), textAlign: TextAlign.right)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: hPct, backgroundColor: Colors.blue.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Colors.blue), minHeight: 8))),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(width: 6),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (1.0 - hPct).clamp(0.0, 1.0), backgroundColor: Colors.red.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Colors.red), minHeight: 8))),
          const SizedBox(width: 8),
          SizedBox(width: 30, child: Text('${a.toInt()}$suffix', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red))),
        ]),
      ]),
    );
  }
}