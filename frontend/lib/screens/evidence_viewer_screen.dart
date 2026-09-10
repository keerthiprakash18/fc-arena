import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dart:typed_data';
import '../config/api.dart';
import '../services/api_service.dart';

class EvidenceViewerView extends StatefulWidget {
  final int leagueId;
  final int matchId;
  const EvidenceViewerView({super.key, required this.leagueId, required this.matchId});
  @override
  State<EvidenceViewerView> createState() => _EvidenceViewerViewState();
}

class _EvidenceViewerViewState extends State<EvidenceViewerView> {
  final _api = ApiService(apiClient);
  List<Map<String, dynamic>> _evidences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final evs = await _api.getMatchEvidences(widget.leagueId, widget.matchId);
      setState(() { _evidences = evs; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  Future<Uint8List?> _fetchBytes(int id) async {
    try {
      final bytes = await _api.getEvidenceFile(widget.leagueId, widget.matchId, id);
      return Uint8List.fromList(bytes);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: Text('Evidence (${_evidences.length})', style: const TextStyle(color: Colors.white)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _evidences.isEmpty
              ? Center(child: Text('No evidence uploaded yet', style: TextStyle(color: FCColors.white30)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _evidences.length,
                  itemBuilder: (_, i) {
                    final ev = _evidences[i];
                    return _evidenceCard(ev);
                  },
                ),
    );
  }

  Widget _evidenceCard(Map<String, dynamic> ev) {
    final id = ev['id'] ?? 0;
    return GestureDetector(
      onTap: () => _openFullScreen(id, ev),
      child: FutureBuilder<Uint8List?>(
        future: _fetchBytes(id),
        builder: (_, snap) {
          return Container(
            decoration: BoxDecoration(
              color: FCColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FCColors.white05),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: FCColors.accent, strokeWidth: 2))
                    : snap.data != null
                        ? Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity)
                        : Center(child: Icon(Icons.broken_image, color: FCColors.white10, size: 40)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(ev['file_name'] ?? 'Evidence', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white))),
                  Text('${ev['file_size'] ?? 0} B', style: TextStyle(fontSize: 10, color: FCColors.white30)),
                ]),
              ),
              if (ev['uploaded_by_name'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('by ${ev['uploaded_by_name']}', style: TextStyle(fontSize: 10, color: FCColors.white30)),
                ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _openFullScreen(int id, Map<String, dynamic> ev) async {
    final bytes = await _fetchBytes(id);
    if (!mounted || bytes == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(ev['file_name'] ?? 'Evidence', style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }
}