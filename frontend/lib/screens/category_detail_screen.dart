import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int leagueId;
  final int categoryId;
  final String categoryName;
  final String color;
  const CategoryDetailScreen({
    super.key,
    required this.leagueId,
    required this.categoryId,
    required this.categoryName,
    required this.color,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final _api = ApiService(apiClient);
  List<PlayerCategoryEntry> _players = [];
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = context.read<AuthProvider>().user?.username;
      var isAdmin = false;
      try {
        final members = await _api.getLeagueMembers(widget.leagueId);
        isAdmin = members.any((m) => m['username'] == me &&
            ['LEAGUE_OWNER', 'LEAGUE_ADMIN'].contains(m['role']));
      } catch (_) {}
      final players = await _api.getCategoryPlayers(widget.leagueId, widget.categoryId);
      if (!mounted) return;
      setState(() {
        _players = players;
        _isAdmin = isAdmin;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color get _color => _parseColor(widget.color);

  Color _parseColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  Future<void> _showAddPlayer() async {
    List<Map<String, dynamic>> members = [];
    try {
      members = await _api.getLeagueMembers(widget.leagueId);
    } catch (_) {}
    final available = members.where((m) => !_players.any((p) => p.username == m['username'])).toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All league members are already in this category'),
          backgroundColor: Colors.amber));
      }
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: FCColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: const Text('Add player to category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(widget.categoryName, style: TextStyle(color: FCColors.white50)),
          ),
          const Divider(color: Colors.white12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(shrinkWrap: true, children: [
              for (final m in available)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _color.withValues(alpha: 0.2),
                    child: Text((m['username'] ?? '?').toString().substring(0, 1).toUpperCase(),
                      style: TextStyle(color: _color, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${m['username']}', style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.add_circle, color: Colors.green),
                  onTap: () => Navigator.pop(ctx, m),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (selected == null) return;
    final playerId = selected['user'] ?? selected['id'];
    if (playerId == null) return;
    try {
      await _api.assignCategoryPlayer(widget.leagueId, widget.categoryId, playerId,
          isPrimary: _players.isEmpty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player added'), backgroundColor: Colors.green));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _removePlayer(PlayerCategoryEntry p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FCColors.surface,
        title: const Text('Remove player?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${p.username} from this category?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.removeCategoryPlayer(widget.leagueId, widget.categoryId, p.playerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player removed'), backgroundColor: Colors.green));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text(widget.categoryName, style: const TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddPlayer,
              backgroundColor: _color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Player'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _players.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people_outline, size: 64, color: FCColors.white15),
                      const SizedBox(height: 16),
                      Text('No players in this category yet', style: TextStyle(color: FCColors.white50)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _players.length,
                        itemBuilder: (_, i) => _playerCard(_players[i]),
                      ),
                    ),
    );
  }

  Widget _playerCard(PlayerCategoryEntry p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: _color.withValues(alpha: 0.2),
          child: Text(p.username.isEmpty ? '?' : p.username[0].toUpperCase(),
            style: TextStyle(color: _color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(p.username, style: const TextStyle(color: Colors.white, fontSize: 15))),
        if (p.isPrimary)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('PRIMARY', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: () => _removePlayer(p),
          ),
      ]),
    );
  }
}