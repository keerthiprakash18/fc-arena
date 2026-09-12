import 'package:flutter/material.dart';

import '../config/api.dart';
import '../models/group.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Group-stage tables for a tournament, with the organizer actions that drive
/// the stage: drawing the groups and promoting the qualifiers.
///
/// Tables are built server-side from verified matches only, so a table of
/// zeroes means the group has not been played — it is never padded with
/// invented results.
class GroupStageView extends StatefulWidget {
  final int leagueId;
  final int tournamentId;
  final bool isAdmin;

  /// Called after the draw or the advancement so the parent can refresh
  /// anything that depends on the fixture list.
  final VoidCallback? onChanged;

  const GroupStageView({
    super.key,
    required this.leagueId,
    required this.tournamentId,
    this.isAdmin = false,
    this.onChanged,
  });

  @override
  State<GroupStageView> createState() => _GroupStageViewState();
}

class _GroupStageViewState extends State<GroupStageView> {
  final _api = ApiService(apiClient);
  List<GroupTable> _groups = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups =
          await _api.getGroupStandings(widget.leagueId, widget.tournamentId);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? FCColors.red : FCColors.accentDark,
    ));
  }

  /// Ask how many groups to create. Blank lets the server derive a sensible
  /// count from the size of the field.
  ///
  /// The dialog returns -1 for Cancel and 0 for "let the league decide", so the
  /// two are never confused with each other.
  Future<void> _draw() async {
    final ctrl = TextEditingController();
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FCColors.surface,
        title: const Text('Draw groups',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Participants are seeded snake-style so the strongest entries are '
            'spread across groups.',
            style: TextStyle(fontSize: 12, color: FCColors.white50),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Number of groups (optional)',
              hintText: 'Leave blank to let the league decide',
              labelStyle: TextStyle(color: FCColors.white50),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Draw'),
          ),
        ],
      ),
    );

    if (count == null || count < 0) return;
    await _run(
      () => _api.drawGroups(widget.leagueId, widget.tournamentId,
          groupCount: count == 0 ? null : count),
      'Groups drawn.',
    );
  }

  Future<void> _advance() async {
    await _run(
      () => _api.advanceGroupWinners(widget.leagueId, widget.tournamentId),
      'Qualifiers advanced into the knockout round.',
    );
  }

  Future<void> _run(
      Future<Map<String, dynamic>> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      final res = await action();
      final message = res['message'];
      if (!mounted) return;
      _toast(message is String && message.isNotEmpty ? message : success);
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: FCColors.accent)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.grid_view, color: FCColors.accent, size: 20),
        const SizedBox(width: 8),
        const Text('GROUP STAGE',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FCColors.white50,
                letterSpacing: 2)),
        const Spacer(),
        if (_busy)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: FCColors.accent)),
      ]),
      const SizedBox(height: 10),
      if (_groups.isEmpty)
        _emptyState()
      else
        ..._groups.map(_groupCard),
      if (widget.isAdmin) ...[
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _draw,
              icon: const Icon(Icons.shuffle, size: 16),
              label: Text(_groups.isEmpty ? 'DRAW GROUPS' : 'REDRAW'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FCColors.accent,
                side: BorderSide(color: FCColors.accent.withValues(alpha: 0.4)),
              ),
            ),
          ),
          if (_groups.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _advance,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('ADVANCE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FCColors.gold,
                  side:
                      BorderSide(color: FCColors.gold.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        ]),
      ],
    ]);
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(Icons.grid_view_outlined, size: 40, color: FCColors.white15),
        const SizedBox(height: 10),
        Text('No groups drawn yet',
            style: TextStyle(color: FCColors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          widget.isAdmin
              ? 'Close registration, then draw the groups to create the fixtures.'
              : 'The organizer has not drawn the groups yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: FCColors.white30),
        ),
      ]),
    );
  }

  Widget _groupCard(GroupTable group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: FCColors.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(group.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Spacer(),
            if (group.isUnplayed)
              Text('not played',
                  style:
                      TextStyle(fontSize: 11, color: FCColors.white30)),
          ]),
        ),
        _tableHeader(),
        ...group.rows.map(_row),
      ]),
    );
  }

  Widget _tableHeader() {
    const style = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: FCColors.white30,
        letterSpacing: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: const Row(children: [
        SizedBox(width: 22),
        Expanded(child: Text('TEAM', style: style)),
        _NumCell('P', style: style),
        _NumCell('W', style: style),
        _NumCell('D', style: style),
        _NumCell('L', style: style),
        _NumCell('GD', style: style),
        _NumCell('PTS', style: style, width: 34),
      ]),
    );
  }

  Widget _row(GroupRow row) {
    // The top two of each group are the usual qualifiers, so give them a
    // subtle marker rather than making the reader work it out.
    final qualifies = row.rank <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: FCColors.white05)),
      ),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text('${row.rank}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: qualifies ? FCColors.accent : FCColors.white30)),
        ),
        Expanded(
          child: Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                color: qualifies ? Colors.white : FCColors.white70,
                fontWeight:
                    qualifies ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
        _NumCell('${row.played}'),
        _NumCell('${row.wins}'),
        _NumCell('${row.draws}'),
        _NumCell('${row.losses}'),
        _NumCell(row.goalDifferenceLabel),
        _NumCell('${row.points}', width: 34, bold: true),
      ]),
    );
  }
}

/// Fixed-width numeric column so the table lines up.
class _NumCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double width;
  final bool bold;

  const _NumCell(this.text, {this.style, this.width = 26, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style ??
            TextStyle(
              fontSize: 12,
              color: bold ? Colors.white : FCColors.white50,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
      ),
    );
  }
}
