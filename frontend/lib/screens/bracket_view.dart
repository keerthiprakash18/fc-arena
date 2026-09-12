import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'match_detail_screen.dart';

/// A real knockout bracket: one column per round, connector lines between
/// them, winners highlighted, horizontally scrollable.
///
/// Layout maths: round `r` holds half as many ties as round `r-1`, so its
/// vertical step doubles each round. Card `i` in round `r` is centred at
/// `(i + 0.5) * step`, which is exactly what makes a tie sit between its two
/// feeder ties without any manual positioning.
class BracketView extends StatefulWidget {
  final int leagueId;
  final int tournamentId;
  const BracketView({super.key, required this.leagueId, required this.tournamentId});

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  static const double _cardWidth = 186;
  static const double _cardHeight = 62;
  static const double _columnGap = 46;
  static const double _rowGap = 14;
  static const double _headerHeight = 30;

  final _api = ApiService(apiClient);
  List<Match> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final matches = await _api.getLeagueMatches(widget.leagueId);
      if (!mounted) return;
      setState(() {
        _matches = matches
            .where((m) => m.tournamentId == widget.tournamentId)
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Rounds in ascending order, each with its fixtures.
  List<_BracketRound> _buildRounds() {
    final byRound = <int, List<Match>>{};
    final unrouted = <Match>[];

    for (final match in _matches) {
      final number = match.roundNumber;
      if (number == null) {
        unrouted.add(match);
      } else {
        byRound.putIfAbsent(number, () => []).add(match);
      }
    }

    final numbers = byRound.keys.toList()..sort();
    final rounds = numbers.map((n) {
      final matches = byRound[n]!;
      // Keep a stable order so a tie always lines up under its feeders.
      matches.sort((a, b) => a.id.compareTo(b.id));
      return _BracketRound(
        number: n,
        name: matches.first.roundName ?? 'Round $n',
        matches: matches,
      );
    }).toList();

    if (unrouted.isNotEmpty) {
      unrouted.sort((a, b) => a.id.compareTo(b.id));
      rounds.add(_BracketRound(
        number: -1,
        name: 'Unassigned',
        matches: unrouted,
        isFallback: true,
      ));
    }
    return rounds;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: FCColors.accent)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: ErrorRetry(message: _error!, onRetry: _load),
      );
    }
    if (_matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FCColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const EmptyState(
          icon: Icons.account_tree_outlined,
          title: 'No bracket yet',
          subtitle: 'Generate fixtures to build the knockout bracket.',
        ),
      );
    }

    final rounds = _buildRounds();
    final step = _cardHeight + _rowGap;

    // A well-formed bracket halves its ties each round, so the first round is
    // the widest and sets the scale. Odd-sized brackets can violate that, so
    // size the canvas to the tallest round instead of trusting round 0.
    var totalHeight = step;
    for (var r = 0; r < rounds.length; r++) {
      final span = rounds[r].matches.length *
          step *
          (rounds[r].isFallback ? 1 : math.pow(2, r).toDouble());
      if (span > totalHeight) totalHeight = span;
    }

    final layout = _layout(rounds, totalHeight, step);

    return Container(
      decoration: BoxDecoration(
        color: FCColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(rounds),
          SizedBox(
            height: totalHeight + _headerHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: rounds.length * (_cardWidth + _columnGap) + _columnGap,
                height: totalHeight + _headerHeight,
                child: Stack(
                  children: [
                    // Connectors sit underneath the cards.
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BracketConnectorPainter(layout: layout),
                      ),
                    ),
                    ...layout.map(_positionedCard),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<_BracketRound> rounds) {
    final completed = _matches.where((m) => m.isVerified).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.account_tree, color: FCColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            'BRACKET',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FCColors.white50,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Text(
            '${rounds.length} round${rounds.length == 1 ? '' : 's'} · '
            '$completed/${_matches.length} played',
            style: TextStyle(fontSize: 11, color: FCColors.white30),
          ),
        ],
      ),
    );
  }

  /// Computes a rectangle for every card, plus the round header positions.
  List<_Slot> _layout(List<_BracketRound> rounds, double totalHeight, double step) {
    final slots = <_Slot>[];

    for (var r = 0; r < rounds.length; r++) {
      final round = rounds[r];
      final left = _columnGap / 2 + r * (_cardWidth + _columnGap);
      // Each round doubles its spacing, so its ties sit between their feeders.
      // The catch-all "Unassigned" column is not part of the tree, so it keeps
      // the base step instead of inheriting an absurd 2^r multiplier.
      final roundStep = step * (round.isFallback ? 1 : math.pow(2, r).toDouble());
      final count = round.matches.length;

      // Centre short rounds vertically against the first round.
      final roundSpan = count * roundStep;
      final offset = (totalHeight - roundSpan) / 2;

      slots.add(_Slot(
        rect: Rect.fromLTWH(left, 4, _cardWidth, _headerHeight - 8),
        header: round.name,
        match: null,
        roundIndex: r,
        isFallback: round.isFallback,
      ));

      for (var i = 0; i < count; i++) {
        final top = _headerHeight + offset + (i + 0.5) * roundStep - _cardHeight / 2;
        slots.add(_Slot(
          rect: Rect.fromLTWH(left, top, _cardWidth, _cardHeight),
          match: round.matches[i],
          roundIndex: r,
          matchIndex: i,
          header: null,
          isFallback: round.isFallback,
        ));
      }
    }
    return slots;
  }

  Widget _positionedCard(_Slot slot) {
    if (slot.match == null) {
      return Positioned(
        left: slot.rect.left,
        top: slot.rect.top,
        width: slot.rect.width,
        height: slot.rect.height,
        child: Center(
          child: Text(
            slot.header!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: FCColors.white50,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: slot.rect.left,
      top: slot.rect.top,
      width: slot.rect.width,
      height: slot.rect.height,
      child: _matchCard(slot.match!),
    );
  }

  Widget _matchCard(Match match) {
    final decided = match.hasScore;
    final homeWon = decided && match.homeScore! > match.awayScore!;
    final awayWon = decided && match.awayScore! > match.homeScore!;
    final live = !decided &&
        !['SCHEDULED', 'CANCELLED'].contains(match.status) &&
        match.status != 'VERIFIED';

    final borderColor = match.isVerified
        ? FCColors.accent.withValues(alpha: 0.45)
        : live
            ? FCColors.amber.withValues(alpha: 0.5)
            : FCColors.white10;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: match.id),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: FCColors.surfaceCard.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _teamRow(match.homeName, match.homeScore, homeWon, decided),
            const SizedBox(height: 3),
            _teamRow(match.awayName, match.awayScore, awayWon, decided),
          ],
        ),
      ),
    );
  }

  Widget _teamRow(String name, int? score, bool won, bool decided) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: decided && !won ? FCColors.white50 : Colors.white,
              fontWeight: won ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 6),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: won ? FCColors.accent : FCColors.white50,
            ),
          ),
        ],
      ],
    );
  }
}

/// One laid-out element: either a round header or a fixture card.
class _Slot {
  final Rect rect;
  final Match? match;
  final String? header;
  final int roundIndex;
  final int matchIndex;
  final bool isFallback;

  _Slot({
    required this.rect,
    this.match,
    this.header,
    this.roundIndex = 0,
    this.matchIndex = 0,
    this.isFallback = false,
  });
}

class _BracketRound {
  final int number;
  final String name;
  final List<Match> matches;

  /// True for the catch-all bucket of fixtures with no round assigned. It is
  /// shown so nothing is silently hidden, but it is not part of the tree.
  final bool isFallback;

  _BracketRound({
    required this.number,
    required this.name,
    required this.matches,
    this.isFallback = false,
  });
}

/// Draws the elbow connectors between a tie and the tie it feeds.
class _BracketConnectorPainter extends CustomPainter {
  final List<_Slot> layout;

  _BracketConnectorPainter({required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    final cards = layout.where((s) => s.match != null).toList();
    if (cards.isEmpty) return;

    final byRound = <int, List<_Slot>>{};
    for (final card in cards) {
      byRound.putIfAbsent(card.roundIndex, () => []).add(card);
    }

    final rounds = byRound.keys.toList()..sort();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = FCColors.accent.withValues(alpha: 0.28);

    for (var i = 0; i < rounds.length - 1; i++) {
      final current = byRound[rounds[i]]!..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
      final next = byRound[rounds[i + 1]]!..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));

      // Nothing feeds the catch-all column, so drawing into it would invent
      // relationships the bracket does not actually have.
      if (next.first.isFallback) continue;

      for (final slot in current) {
        // A tie feeds the parent at half its index; a bye has no feeder line.
        final parentIndex = slot.matchIndex ~/ 2;
        if (parentIndex >= next.length) continue;
        final parent = next[parentIndex];

        final start = Offset(slot.rect.right, slot.rect.center.dy);
        final end = Offset(parent.rect.left, parent.rect.center.dy);
        final midX = (start.dx + end.dx) / 2;

        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(midX, start.dy)
          ..lineTo(midX, end.dy)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter old) {
    if (old.layout.length != layout.length) return true;
    // Connector geometry is derived from the rects, so a round changing shape
    // (a bye appearing, a fixture moving) has to trigger a repaint.
    for (var i = 0; i < layout.length; i++) {
      if (old.layout[i].rect != layout[i].rect) return true;
    }
    return false;
  }
}
