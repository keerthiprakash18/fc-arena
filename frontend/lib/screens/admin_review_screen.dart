import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/api.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';
import 'review_detail_screen.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});
  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  PendingReviewsData? _data;
  bool _loading = true;
  bool _isAdmin = true;
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
      final data = await _api.getPendingReviews(_leagueId);
      setState(() { _data = data; _loading = false; });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _isAdmin = e.statusCode != 403;
        _error = _isAdmin ? e.message : null;
      });
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
        title: const Text('Review Verification', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : !_isAdmin
              ? _locked()
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('PENDING REVIEWS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          if (_data!.reviews.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(12)),
                              child: Column(children: [
                                Icon(Icons.task_alt, size: 48, color: Colors.green.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('All caught up!', style: TextStyle(color: FCColors.white50)),
                                Text('No verifications waiting for review.', style: TextStyle(fontSize: 12, color: FCColors.white30)),
                              ]),
                            )
                          else
                            ..._data!.reviews.map((r) => _reviewCard(r)),
                          if (_data!.disputes.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('OPEN DISPUTES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 2)),
                            const SizedBox(height: 12),
                            ..._data!.disputes.map((d) => _disputeCard(d)),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _locked() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock, size: 64, color: FCColors.white10),
        const SizedBox(height: 16),
        Text('Admin access only', style: TextStyle(color: FCColors.white50)),
        const SizedBox(height: 4),
        Text('League owner/admins can review verifications', style: TextStyle(fontSize: 12, color: FCColors.white30)),
      ]),
    );
  }

  Widget _reviewCard(AdminReviewItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            '${task.homeUsername} vs ${task.awayUsername}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: const Text('REVIEW', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Confidence: ${task.confidence != null ? '${(task.confidence! * 100).toStringAsFixed(0)}%' : 'N/A'}',
          style: TextStyle(fontSize: 13, color: FCColors.white50)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 42,
          child: OutlinedButton(
            onPressed: () async {
              final done = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => ReviewDetailScreen(
                  leagueId: _leagueId, matchId: task.matchId, taskId: task.taskId,
                )),
              );
              if (done == true) _load();
            },
            style: OutlinedButton.styleFrom(foregroundColor: FCColors.accent, side: const BorderSide(color: FCColors.accent)),
            child: const Text('REVIEW NOW'),
          ),
        ),
      ]),
    );
  }

  Widget _disputeCard(Map<String, dynamic> dispute) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FCColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text('Match #${dispute['match_id']} â€” raised by ${dispute['raised_by']}',
            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text('${dispute['reason']}', style: TextStyle(fontSize: 12, color: FCColors.white50)),
      ]),
    );
  }
}