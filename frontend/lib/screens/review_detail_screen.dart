import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/dashboard.dart';
import '../models/match.dart';
import '../services/api_service.dart';

class ReviewDetailScreen extends StatefulWidget {
  final int leagueId;
  final int matchId;
  final int taskId;
  const ReviewDetailScreen({super.key, required this.leagueId, required this.matchId, required this.taskId});
  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  final _api = ApiService(apiClient);
  VerificationTask? _task;
  Match? _match;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final task = await _api.getVerificationTask(widget.leagueId, widget.matchId);
      Match? match;
      try {
        match = await _api.getMatch(widget.leagueId, widget.matchId);
      } catch (_) {}
      setState(() { _task = task; _match = match; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _review({required bool approved}) async {
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(approved ? 'Approve Verification' : 'Reject Verification',
          style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: notesCtrl,
          minLines: 2, maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: approved ? 'Optional note...' : 'Reason for rejection (required)',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approved ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(approved ? 'APPROVE' : 'REJECT'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final notes = notesCtrl.text.trim();
    if (!approved && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejection requires a reason'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.adminReview(widget.leagueId, widget.matchId, approved: approved, notes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approved ? 'Verification approved — match verified!' : 'Verification rejected'),
          backgroundColor: approved ? Colors.green : Colors.red,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text('Review Match #${widget.matchId}', style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _submittedScoreCard(),
                    const SizedBox(height: 16),
                    _taskSummary(),
                    const SizedBox(height: 16),
                    _extractedDataCard(),
                    const SizedBox(height: 24),
                    _actionButtons(),
                  ],
                ),
    );
  }

  Widget _submittedScoreCard() {
    final m = _match;
    if (m == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFe94560), Color(0xFF0f3460)]), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text('${m.homeUsername ?? 'Home'} vs ${m.awayUsername ?? 'Away'}', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        Text(m.scoreDisplay, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Submitted score', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _taskSummary() {
    final t = _task!;
    final items = <(String, String)>[
      ('Status', t.status.replaceAll('_', ' ')),
      ('AI Provider', t.aiProvider ?? '—'),
      ('Confidence', t.aiConfidenceScore != null ? '${(double.tryParse(t.aiConfidenceScore.toString())! * 100).toStringAsFixed(1)}%' : '—'),
      ('Evidence', t.evidenceFile ?? '—'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VERIFICATION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 10),
        ...items.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text('${e.$1}: ', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
            Text(e.$2, style: const TextStyle(fontSize: 13, color: Colors.white)),
          ]),
        )),
      ]),
    );
  }

  Widget _extractedDataCard() {
    final results = _task?.results ?? [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AI EXTRACTED DATA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
        const SizedBox(height: 10),
        if (results.isEmpty)
          Text('No extraction results', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)))
        else
          ...results.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.isReliable ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (r.isReliable ? Colors.green : Colors.orange).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Expanded(child: Text(r.fieldName, style: const TextStyle(fontSize: 13, color: Colors.white))),
              Text(r.fieldValue, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              if (r.confidence != null) ...[
                const SizedBox(width: 8),
                Text('${(r.confidence! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: (r.isReliable ? Colors.green : Colors.orange))),
              ],
            ]),
          )),
      ]),
    );
  }

  Widget _actionButtons() {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : () => _review(approved: true),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : () => _review(approved: false),
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('REJECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ),
    ]);
  }
}