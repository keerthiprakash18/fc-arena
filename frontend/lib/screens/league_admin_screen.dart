import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api.dart';
import '../services/api_service.dart';

class LeagueAdminScreen extends StatefulWidget {
  const LeagueAdminScreen({super.key});
  @override
  State<LeagueAdminScreen> createState() => _LeagueAdminScreenState();
}

class _LeagueAdminScreenState extends State<LeagueAdminScreen> {
  final _api = ApiService(apiClient);
  Map<String, dynamic>? _league;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final leagues = await _api.getMyLeaguesAdmin();
      if (leagues.isEmpty) {
        setState(() { _loading = false; });
        return;
      }
      final league = leagues.first;
      _nameCtrl.text = league['name'] ?? '';
      _descCtrl.text = league['description'] ?? '';
      final members = await _api.getLeagueMembers(league['id']);
      setState(() { _league = league; _members = members; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('League Admin', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _league == null
              ? Center(child: Text('No league found', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _leagueCard(),
                    const SizedBox(height: 16),
                    _membersHeader(),
                    ..._members.map((m) => _memberTile(m)),
                  ]),
                ),
    );
  }

  Widget _leagueCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF0f3460)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_league!['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
          GestureDetector(
            onTap: _editLeague,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('Edit', style: TextStyle(fontSize: 12, color: Colors.white)),
              ]),
            ),
          ),
        ]),
        if ((_league!['description'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_league!['description'], style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: _league!['league_code'] ?? ''));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('League code copied!'), backgroundColor: Colors.green));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.copy, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text(_league!['league_code'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2)),
              const SizedBox(width: 6),
              Text('tap to copy', style: TextStyle(fontSize: 11, color: Colors.amber.withValues(alpha: 0.6))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text('${_league!['member_count'] ?? _members.length} members', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _membersHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('MEMBERS (${_members.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1)),
    );
  }

  Widget _memberTile(Map<String, dynamic> m) {
    final role = m['role'] ?? 'PLAYER';
    final userName = m['username'] ?? '?';
    final isOwner = role == 'LEAGUE_OWNER';
    final roleColor = role == 'LEAGUE_OWNER' ? Colors.amber
        : role == 'LEAGUE_ADMIN' ? Colors.cyan
            : Colors.white54;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: roleColor.withValues(alpha: 0.2),
          child: Text(userName[0].toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: roleColor)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(userName, style: const TextStyle(fontSize: 14, color: Colors.white)),
          Text(role.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: roleColor.withValues(alpha: 0.8))),
        ])),
        if (!isOwner) ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            color: const Color(0xFF1a1a2e),
            onSelected: (v) {
              if (v == 'ADMIN' || v == 'PLAYER' || v == 'TOURNAMENT_ADMIN') {
                _setRole(m, v);
              } else if (v == 'REMOVE') {
                _removeMember(m);
              }
            },
            itemBuilder: (_) => [
              if (role != 'LEAGUE_ADMIN')
                const PopupMenuItem(value: 'ADMIN', child: Text('Promote to Admin', style: TextStyle(color: Colors.cyan)))
              else
                const PopupMenuItem(value: 'PLAYER', child: Text('Demote to Player', style: TextStyle(color: Colors.white70))),
              const PopupMenuItem(value: 'TOURNAMENT_ADMIN', child: Text('Make Tournament Admin', style: TextStyle(color: Colors.white70))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'REMOVE', child: Text('Remove from League', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ]),
    );
  }

  Future<void> _setRole(Map<String, dynamic> m, String role) async {
    try {
      await _api.updateMemberRole(_league!['id'], m['user'], role);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeMember(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text('Remove ${m['username']}?', style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text('They will be removed from the league. Matches keep their history.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.removeMember(_league!['id'], m['user']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editLeague() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Edit League', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'League Name', labelStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white54)), maxLines: 3),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _api.updateLeague(_league!['id'], name: _nameCtrl.text, description: _descCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('League updated'), backgroundColor: Colors.green));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }
}