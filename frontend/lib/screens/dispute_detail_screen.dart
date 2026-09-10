import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/dispute.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DisputeDetailScreen extends StatefulWidget {
  final int leagueId;
  final int disputeId;
  const DisputeDetailScreen({super.key, required this.leagueId, required this.disputeId});
  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  final _api = ApiService(apiClient);
  Dispute? _dispute;
  bool _loading = true;
  String? _error;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dispute = await _api.getDispute(widget.leagueId, widget.disputeId);
      setState(() { _dispute = dispute; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await _api.addDisputeComment(widget.leagueId, widget.disputeId, text);
      _commentCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _posting = false);
  }

  Future<void> _resolve() async {
    final resolution = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FCColors.surface,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Resolve Dispute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        const Divider(color: Colors.white12),
        for (final r in [
          ('ACCEPTED', 'Accepted'),
          ('REJECTED', 'Rejected'),
          ('CORRECTED', 'Corrected'),
        ])
        ListTile(
          leading: Icon(Icons.gavel, color: Colors.white54),
          title: Text(r.$2, style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, r.$1),
        ),
      ])),
    );
    if (resolution == null) return;
    if (!mounted) return;

    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FCColors.surface,
        title: Text('Resolve as $resolution', style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: notesCtrl,
          minLines: 2, maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Resolution notes (optional)', hintStyle: TextStyle(color: FCColors.white30)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('RESOLVE')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.resolveDispute(widget.leagueId, widget.disputeId,
        resolution: resolution, resolutionNotes: notesCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute resolved'), backgroundColor: Colors.green));
      }
      await _load();
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
        title: Text('Dispute #${widget.disputeId}', style: const TextStyle(color: Colors.white)),
        actions: [
          if (_dispute?.isOpen ?? false)
            IconButton(
              icon: const Icon(Icons.gavel, color: Colors.green),
              tooltip: 'Resolve (admin)',
              onPressed: _resolve,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _headerCard(),
                    const SizedBox(height: 16),
                    if (_dispute!.comments.isNotEmpty) ...[
                      const Text('COMMENTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      ..._dispute!.comments.map((c) => _commentBubble(c)),
                      const SizedBox(height: 8),
                    ],
                    _commentInput(),
                  ],
                ),
    );
  }

  Widget _headerCard() {
    final d = _dispute!;
    final color = d.isOpen ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Match #${d.matchId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(d.status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(d.reasonLabel, style: TextStyle(fontSize: 14, color: Colors.amber.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(d.description, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 10),
        Text('Raised by ${d.raisedByName ?? '?'}', style: TextStyle(fontSize: 12, color: FCColors.white30)),
        if (d.resolution != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text('Resolved: ${d.resolutionLabel}', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
          ]),
          if ((d.resolutionNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(d.resolutionNotes!, style: TextStyle(fontSize: 12, color: FCColors.white50)),
          ],
        ],
      ]),
    );
  }

  Widget _commentBubble(DisputeComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(comment.username, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FCColors.accent)),
          const Spacer(),
          Text(comment.createdAt, style: TextStyle(fontSize: 10, color: FCColors.white30)),
        ]),
        const SizedBox(height: 4),
        Text(comment.comment, style: const TextStyle(fontSize: 13, color: Colors.white)),
      ]),
    );
  }

  Widget _commentInput() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _commentCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Add comment...',
            hintStyle: TextStyle(color: FCColors.white30),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onSubmitted: (_) => _postComment(),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: _posting
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: FCColors.accent, strokeWidth: 2))
            : const Icon(Icons.send, color: FCColors.accent),
        onPressed: _posting ? null : _postComment,
      ),
    ]);
  }
}