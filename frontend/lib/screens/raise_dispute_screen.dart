import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../models/dispute.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RaiseDisputeScreen extends StatefulWidget {
  const RaiseDisputeScreen({super.key});
  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen> {
  final _api = ApiService(apiClient);
  List<Match> _myMatches = [];
  bool _loading = true;
  String? _error;
  int _leagueId = 1;
  int? _selectedMatchId;
  String? _selectedReason;
  final _descriptionCtrl = TextEditingController();
  bool _submitting = false;

  static const _reasons = [
    ('WRONG_SCORE', 'Wrong Score'),
    ('WRONG_OPPONENT', 'Wrong Opponent'),
    ('INVALID_SCREENSHOT', 'Invalid Screenshot'),
    ('INCORRECT_STATISTICS', 'Incorrect Statistics'),
    ('CHEATING', 'Cheating'),
    ('OTHER', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      if (!mounted) return;
      final me = context.read<AuthProvider>().user;
      final matches = await _api.getLeagueMatches(_leagueId);
      final mine = matches.where((m) => m.homeUserId == me?.id || m.awayUserId == me?.id).toList();
      setState(() { _myMatches = mine; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _submit() async {
    if (_selectedMatchId == null || _selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select match and reason')));
      return;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe the issue')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.createDispute(_leagueId, DisputeCreateData(
        matchId: _selectedMatchId!,
        reason: _selectedReason!,
        description: _descriptionCtrl.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute raised!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(backgroundColor: FCColors.surface, title: const Text('Raise Dispute', style: TextStyle(color: Colors.white))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('SELECT MATCH (participant only)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    if (_myMatches.isEmpty)
                      Text('No eligible matches. Only your own matches can be disputed.', style: const TextStyle(color: Colors.white54))
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedMatchId,
                        dropdownColor: FCColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true, fillColor: FCColors.white05,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        isExpanded: true,
                        hint: Text('Choose match', style: TextStyle(color: FCColors.white30)),
                        items: _myMatches.map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text('Match #${m.id} â€” ${m.homeUsername ?? ''} vs ${m.awayUsername ?? ''} (${m.status.replaceAll('_', ' ')})',
                            style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedMatchId = v),
                      ),
                    const SizedBox(height: 20),
                    const Text('REASON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _reasons.map((r) => ChoiceChip(
                        label: Text(r.$2, style: TextStyle(fontSize: 12, color: _selectedReason == r.$1 ? Colors.white : Colors.white70)),
                        selected: _selectedReason == r.$1,
                        onSelected: (_) => setState(() => _selectedReason = r.$1),
                        selectedColor: FCColors.accent,
                        backgroundColor: FCColors.white05,
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text('DESCRIPTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionCtrl,
                      minLines: 4, maxLines: 8,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: 'Explain what happened...', hintStyle: TextStyle(color: FCColors.white30)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: FCColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _submitting
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('RAISE DISPUTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
    );
  }
}