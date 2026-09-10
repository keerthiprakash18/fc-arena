import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});
  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _api = ApiService(apiClient);
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;
  bool _creating = false;
  int _leagueId = 1;
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final leagues = await _api.getMyLeagues();
      if (leagues.isNotEmpty) _leagueId = leagues.first['id'];
      if (!mounted) return;
      final me = context.read<AuthProvider>().user;
      final members = await _api.getLeagueMembers(_leagueId);
      final others = members.where((m) => m['user'] != me?.id).toList();
      setState(() { _members = others; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _createMatch() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an opponent')));
      return;
    }
    setState(() => _creating = true);
    try {
      final match = await _api.createMatch(_leagueId, awayUserId: _selectedUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match #${match.id} created!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('New Match Challenge', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _members.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.group_off, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text('No opponents available', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Choose your opponent', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _members.length,
                            itemBuilder: (_, i) => _memberTile(_members[i]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity, height: 52,
                            child: ElevatedButton(
                              onPressed: _creating ? null : _createMatch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFe94560),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _creating
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('CREATE MATCH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final userId = member['user'] as int? ?? 0;
    final selected = userId == _selectedUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFe94560).withValues(alpha: 0.15) : const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? const Color(0xFFe94560) : Colors.white.withValues(alpha: 0.1), width: selected ? 1.5 : 1),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedUserId = userId),
        leading: CircleAvatar(
          backgroundColor: selected ? const Color(0xFFe94560) : Colors.white.withValues(alpha: 0.1),
          child: Text(
            (member['username'] ?? '?').toString()[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
        subtitle: Text('${member['email'] ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xFFe94560) : Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}