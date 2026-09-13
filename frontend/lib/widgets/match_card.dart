import 'dart:async';

import 'package:flutter/material.dart';

import '../models/match.dart';
import '../theme/app_theme.dart';
import 'fc_animations.dart';

/// Whether the platform has asked us to stop animating.
///
/// `fc_animations.dart` keeps its own copy of this privately; widgets that live
/// outside it need the same check so reduce-motion is honoured consistently.
bool _reduced(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A professional fixture card: round header, both sides with crests, the score
/// or a VS marker, kick-off time and a status badge.
///
/// The card animates in when it first appears and animates its score when the
/// result changes, but paints its final state immediately under reduce-motion.
class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;

  /// Position in the list, used to stagger the entry animation so a column of
  /// cards cascades instead of all snapping in at once.
  final int index;

  /// Compact mode drops the round header and venue for dense lists.
  final bool compact;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.index = 0,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return _card(context);

    // Cap the stagger so a long list does not leave later cards waiting.
    final delay = Duration(milliseconds: 40 * (index % 8));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // Clamp the delayed portion so the first `delay` is a hold at zero.
        final progress =
            ((t * (260 + delay.inMilliseconds) - delay.inMilliseconds) /
                    260)
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final decided = match.hasScore;
    final homeWon = match.outcome == 1;
    final awayWon = match.outcome == -1;
    final isLive = match.status == 'IN_PROGRESS';
    final accent = isLive ? FCColors.red : match.statusColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: FCColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive
                ? FCColors.red.withValues(alpha: 0.55)
                : match.isVerified
                    ? FCColors.accent.withValues(alpha: 0.28)
                    : FCColors.white10,
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          if (!compact) _header(accent, isLive),
          Padding(
            padding: EdgeInsets.fromLTRB(12, compact ? 10 : 8, 12, 10),
            child: Row(children: [
              Expanded(
                child: _side(
                  name: match.homeShort,
                  logo: match.homeTeamLogo,
                  alignEnd: true,
                  dimmed: decided && !homeWon,
                  won: decided && homeWon,
                ),
              ),
              _centre(decided, accent, isLive),
              Expanded(
                child: _side(
                  name: match.awayShort,
                  logo: match.awayTeamLogo,
                  alignEnd: false,
                  dimmed: decided && !awayWon,
                  won: decided && awayWon,
                ),
              ),
            ]),
          ),
          if (!compact) _footer(accent, isLive),
        ]),
      ),
    );
  }

  Widget _header(Color accent, bool isLive) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: FCColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(children: [
        if (match.roundName != null) ...[
          Text(
            match.roundName!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: FCColors.white50,
            ),
          ),
        ] else
          Text(
            match.isTeamMatch ? 'TEAM FIXTURE' : 'FRIENDLY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: FCColors.white30,
            ),
          ),
        const Spacer(),
        if (isLive) ...[
          _LiveDot(),
          const SizedBox(width: 5),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            isLive ? 'LIVE' : match.statusLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: accent,
            ),
          ),
        ),
      ]),
    );
  }

  /// One side of the fixture: crest plus short name. The crest sits on the
  /// outer edge, so the two logos frame the centre and the names face inward.
  Widget _side({
    required String name,
    required String? logo,
    required bool alignEnd,
    required bool dimmed,
    required bool won,
  }) {
    final crest = TeamLogo(logoUrl: logo, initials: _initials(name), size: 42);
    final label = Flexible(
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 13,
          height: 1.15,
          fontWeight: won ? FontWeight.w800 : FontWeight.w600,
          color: dimmed ? FCColors.white30 : Colors.white,
        ),
      ),
    );

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [label, const SizedBox(width: 8), crest]
          : [crest, const SizedBox(width: 8), label],
    );
  }

  Widget _centre(bool decided, Color accent, bool isLive) {
    if (!decided) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            FCColors.accent.withValues(alpha: 0.18),
            FCColors.cyan.withValues(alpha: 0.18),
          ]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'VS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _AnimatedScore(value: match.homeScore!, accent: accent),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text('-',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: FCColors.white30)),
        ),
        _AnimatedScore(value: match.awayScore!, accent: accent),
      ]),
    );
  }

  Widget _footer(Color accent, bool isLive) {
    final when = _formatKickoff(match.scheduledAt);
    final parts = <String>[
      ?when,
      if (match.venue.isNotEmpty) match.venue,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(children: [
        if (parts.isNotEmpty) ...[
          Icon(Icons.schedule, size: 12, color: FCColors.white30),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              parts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: FCColors.white50),
            ),
          ),
        ],
        const Spacer(),
        // Only a match that has not started can have a meaningful countdown.
        if (match.isScheduled && match.scheduledAt != null)
          _Countdown(target: match.scheduledAt!),
      ]),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.length >= 2
          ? words.first.substring(0, 2).toUpperCase()
          : words.first.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// A score that pops when it changes, so a goal is visible without a rebuild
/// flashing past unnoticed.
class _AnimatedScore extends StatelessWidget {
  final int value;
  final Color accent;

  const _AnimatedScore({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return _text();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(begin: 1.6, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _text(),
    );
  }

  Widget _text() => Text(
        '$value',
        // The key is what makes AnimatedSwitcher treat a new score as new.
        key: ValueKey(value),
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      );
}

/// Live indicator with a gentle pulse.
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return _liveDot;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: _liveDot,
    );
  }

  Widget get _liveDot => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: FCColors.red,
          shape: BoxShape.circle,
        ),
      );
}

/// Ticking countdown to kick-off.
///
/// Rebuilds only when the rendered string actually changes, so a fixture three
/// days away costs one rebuild a minute rather than one a second.
class _Countdown extends StatefulWidget {
  final String target;

  const _Countdown({required this.target});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _label = _format();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _format();
      if (next != _label && mounted) setState(() => _label = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_label.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(Icons.timer_outlined, size: 12, color: FCColors.cyan),
      const SizedBox(width: 4),
      Text(
        _label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FCColors.cyan,
        ),
      ),
    ]);
  }

  /// Compact countdown showing only the two most significant units.
  String _format() {
    final kickoff = DateTime.tryParse(widget.target);
    if (kickoff == null) return '';
    final left = kickoff.difference(DateTime.now());
    if (left.isNegative) return 'Starting soon';

    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final seconds = left.inSeconds % 60;

    if (days > 0) return 'in ${days}d ${hours}h';
    if (hours > 0) return 'in ${hours}h ${minutes}m';
    if (minutes > 0) return 'in ${minutes}m ${seconds}s';
    return 'in ${seconds}s';
  }
}

/// "8:30 PM · SEP 15" — local time, short month, no year when it is this year.
String? _formatKickoff(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final local = dt.toLocal();

  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';

  return '$hour12:$minute $period  ·  ${months[local.month - 1]} ${local.day}';
}
