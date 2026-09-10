import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _api = ApiService(apiClient);
  List<Category> _categories = [];
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
      final cats = await _api.getCategories(_leagueId);
      setState(() { _categories = cats; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _createCategory() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController(text: '2000');
    String selectedColor = '#e94560';
    final colors = ['#e94560', '#0f3460', '#16c79a', '#f5a623', '#7b2ff7', '#00b4d8'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('New Category', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Name (e.g. Open, Under-15)', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)))),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Description', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Min Rating', labelStyle: TextStyle(color: Colors.white54)))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Max Rating', labelStyle: TextStyle(color: Colors.white54)))),
            ]),
            const SizedBox(height: 10),
            Row(children: colors.map((c) => GestureDetector(
              onTap: () => setDState(() => selectedColor = c),
              child: Container(
                width: 32, height: 32, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: _parseColor(c), borderRadius: BorderRadius.circular(8),
                  border: selectedColor == c ? Border.all(color: Colors.white, width: 2) : null),
              ),
            )).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _parseColor(selectedColor)), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await _api.createCategory(_leagueId,
        name: nameCtrl.text.trim(), description: descCtrl.text.trim(),
        minRating: double.tryParse(minCtrl.text) ?? 0,
        maxRating: double.tryParse(maxCtrl.text) ?? 2000,
        color: selectedColor,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category created'), backgroundColor: Colors.green));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Categories', style: TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCategory,
        backgroundColor: const Color(0xFF7b2ff7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : _categories.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.category, size: 64, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      Text('No categories yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) => _catCard(_categories[i]),
                      ),
                    ),
    );
  }

  Widget _catCard(Category cat) {
    final color = _parseColor(cat.color);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          leagueId: _leagueId,
          categoryId: cat.id,
          categoryName: cat.name,
          color: cat.color,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.category, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text('${cat.minRating.toStringAsFixed(0)} – ${cat.maxRating.toStringAsFixed(0)} rating', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ])),
          Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${cat.playerCount}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text('players', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ]),
        ]),
      ),
    );
  }
}