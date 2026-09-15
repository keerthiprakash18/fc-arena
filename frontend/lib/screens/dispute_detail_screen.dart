import 'package:flutter/material.dart';

import '../config/api.dart';
import '../models/dispute.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart' show showAuthSnack;

/// The resolution actions the API accepts, with the labels an admin should see.
///
/// Mirrors `Dispute.RESOLUTION_CHOICES` server-side; the server is still the
/// authority and rejects anything else.
const Map<String, String> _resolutionLabels = {
  'ACCEPTED': 'Accept the dispute',
  'REJECTED': 'Reject the dispute',
  'CORRECTED': 'Mark as corrected',
};

const Map<String, String> _resolutionHelp = {
  'ACCEPTED': 'The result stands as disputed and will be re-examined.',
  'REJECTED': 'The recorded result is correct; the dispute is dismissed.',
  'CORRECTED': 'The result was wrong and has been amended.',
};

/// Full view of a single dispute: the complaint, its thread, and — for league
/// admins — the controls to resolve it.
///
/// Previously the admin review screen listed open disputes as inert cards, so a
/// dispute could be seen but never acted on even though the API has supported
/// resolution all along.
class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({
    super.key,
    required this.leagueId,
    required this.disputeId,
    this.isAdmin = false,
  });

  final int leagueId;
  final int disputeId;

  /// Whether to offer the resolve controls. The server enforces this too.
  final bool isAdmin;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  final _api = ApiService(apiClient);
  final _commentController = TextEditingController();

  Dispute? _dispute;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dispute = await _api.getDispute(widget.leagueId, widget.disputeId);
      if (!mounted) return;
      setState(() {
        _dispute = dispute;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _api.addDisputeComment(widget.leagueId, widget.disputeId, text);
      _commentController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is ApiException ? e.message : '$e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve(String resolution) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FCColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _resolutionLabels[resolution] ?? 'Resolve',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _resolutionHelp[resolution] ?? '',
              style: TextStyle(fontSize: 13, color: FCColors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Resolution notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('CANCEL', style: TextStyle(color: FCColors.white40)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      notesController.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await _api.resolveDispute(
        widget.leagueId,
        widget.disputeId,
        resolution: resolution,
        resolutionNotes: notesController.text.trim(),
      );
      if (!mounted) return;
      showAuthSnack(context, 'Dispute resolved.');
      await _load();
    } catch (e) {
      if (mounted) {
        showAuthSnack(context, e is ApiException ? e.message : '$e', error: true);
      }
    } finally {
      notesController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return FCColors.red;
      case 'UNDER_REVIEW':
        return FCColors.gold;
      case 'RESOLVED':
        return FCColors.green;
      default:
        return FCColors.white40;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Dispute', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? FCErrorRetry(message: _error!, onRetry: _load)
              : _body(_dispute!),
    );
  }

  Widget _body(Dispute dispute) {
    final isOpen = dispute.status == 'OPEN' || dispute.status == 'UNDER_REVIEW';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FCColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _statusColor(dispute.status).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, size: 18, color: _statusColor(dispute.status)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Match #${dispute.matchId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  FCStatusBadge(
                    text: dispute.status.replaceAll('_', ' '),
                    color: _statusColor(dispute.status),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FCInfoRow(
                icon: Icons.report_outlined,
                label: 'Reason',
                value: dispute.reason,
              ),
              if (dispute.raisedByName != null)
                FCInfoRow(
                  icon: Icons.person_outline,
                  label: 'Raised by',
                  value: dispute.raisedByName!,
                ),
              FCInfoRow(
                icon: Icons.schedule_outlined,
                label: 'Opened',
                value: _formatDate(dispute.createdAt),
              ),
              if (dispute.resolution != null) ...[
                const SizedBox(height: 8),
                FCInfoRow(
                  icon: Icons.gavel_outlined,
                  label: 'Resolution',
                  value: dispute.resolution!,
                  iconColor: FCColors.green,
                ),
                if (dispute.resolvedByName != null)
                  FCInfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Resolved by',
                    value: dispute.resolvedByName!,
                  ),
              ],
              const SizedBox(height: 14),
              Text(
                dispute.description,
                style: TextStyle(fontSize: 13, height: 1.5, color: FCColors.white60),
              ),
              if ((dispute.resolutionNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FCColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FCColors.green.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESOLUTION NOTES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: FCColors.green.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dispute.resolutionNotes!,
                        style: TextStyle(fontSize: 13, height: 1.4, color: FCColors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        if (widget.isAdmin && isOpen) ...[
          const SizedBox(height: 24),
          const FCSectionHeader(title: 'RESOLVE'),
          const SizedBox(height: 12),
          for (final entry in _resolutionLabels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _resolve(entry.key),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _statusColor('OPEN').withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],

        const SizedBox(height: 24),
        FCSectionHeader(title: 'DISCUSSION (${dispute.comments.length})'),
        const SizedBox(height: 12),
        if (dispute.comments.isEmpty)
          Text(
            'No comments yet.',
            style: TextStyle(fontSize: 13, color: FCColors.white40),
          )
        else
          for (final comment in dispute.comments) _commentTile(comment),

        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _busy ? null : _addComment,
              icon: const Icon(Icons.send_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: FCColors.accent,
                foregroundColor: FCColors.pitch,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentTile(DisputeComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FCColors.white05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FCColors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.username,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                _formatDate(comment.createdAt),
                style: TextStyle(fontSize: 11, color: FCColors.white30),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.comment,
            style: TextStyle(fontSize: 13, height: 1.4, color: FCColors.white60),
          ),
        ],
      ),
    );
  }

  /// Render an ISO timestamp as a short, readable local date.
  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
