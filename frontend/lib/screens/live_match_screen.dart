import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fc_animations.dart';

/// A dedicated live-match view with score, timeline, and goal celebration.
///
/// This is a richer presentation of a match than [MatchDetailScreen]: it is
/// meant to be watched during play, so the score is enormous, events are
/// chronological, and a goal triggers a full-screen confetti animation.
class LiveMatchScreen extends StatefulWidget {
  final int leagueId;
  final int matchId;

  const LiveMatchScreen({super.key, required this.leagueId, required this.matchId});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen>
    with TickerProviderStateMixin {
  final _api = ApiService(apiClient);
  Match? _match;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  /// Last known score so we can detect a change and celebrate.
  int? _lastHome;
  int? _lastAway;

  late AnimationController _goalController;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    _goalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _celebrating = false);
          _goalController.reset();
        }
      });
    _load();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final match = await _api.getMatch(widget.leagueId, widget.matchId);
      final events = await _api.getMatchEvents(widget.leagueId, widget.matchId);
      if (!mounted) return;

      final newHome = match.homeScore;
      final newAway = match.awayScore;
      final scoreChanged = (_lastHome != null && _lastAway != null) &&
          (newHome != _lastHome || newAway != _lastAway);

      setState(() {
        _match = match;
        _events = events;
        _loading = false;
        _error = null;
        _lastHome = newHome;
        _lastAway = newAway;
      });

      if (scoreChanged && (newHome != null && newAway != null)) {
        _triggerGoal();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _triggerGoal() {
    setState(() => _celebrating = true);
    _goalController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Live Match', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : Stack(children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    color: FCColors.accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _scoreBoard(),
                          const SizedBox(height: 20),
                          _statusBar(),
                          const SizedBox(height: 24),
                          const FCSectionHeader(title: 'TIMELINE'),
                          const SizedBox(height: 12),
                          _timeline(),
                        ],
                      ),
                    ),
                  ),
                  if (_celebrating) _goalOverlay(),
                ]),
    );
  }

  Widget _scoreBoard() {
    final m = _match!;
    final home = m.homeName;
    final away = m.awayName;
    final homeScore = m.homeScore;
    final awayScore = m.awayScore;
    final hasScore = homeScore != null && awayScore != null;

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TeamLogo(initials: _initials(home), size: 52),
                    const SizedBox(height: 10),
                    Text(home,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    AnimatedCounter(
                      value: hasScore ? homeScore : 0,
                      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text('—', style: TextStyle(fontSize: 20, color: FCColors.white30)),
                    const SizedBox(height: 4),
                    AnimatedCounter(
                      value: hasScore ? awayScore : 0,
                      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    TeamLogo(initials: _initials(away), size: 52),
                    const SizedBox(height: 10),
                    Text(away,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (m.venue.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 14, color: FCColors.white30),
                const SizedBox(width: 4),
                Text(m.venue, style: TextStyle(fontSize: 12, color: FCColors.white30)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusBar() {
    final m = _match!;
    final color = m.status == 'VERIFIED'
        ? Colors.green
        : m.status == 'SCHEDULED'
            ? FCColors.amber
            : FCColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            m.statusLabel,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          if (m.scheduledAt != null) ...[
            const SizedBox(width: 12),
            Text(
              m.scheduledAt!.substring(0, 16).replaceFirst('T', ' '),
              style: TextStyle(fontSize: 12, color: FCColors.white30),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeline() {
    if (_events.isEmpty) {
      return Text('No events recorded yet', style: TextStyle(color: FCColors.white30));
    }
    return Column(
      children: _events.map((e) {
        final type = e['event_type'] as String? ?? '';
        final minute = e['minute'] as int? ?? 0;
        final player = e['username'] as String? ?? 'Unknown';
        final desc = e['description'] as String? ?? '';
        final icon = _eventIcon(type);
        final color = _eventColor(type);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: FCColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_eventLabel(type)} — $player',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    if (desc.isNotEmpty)
                      Text(desc, style: TextStyle(fontSize: 11, color: FCColors.white30)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FCColors.white05,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "$minute'",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FCColors.white50),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _goalOverlay() {
    return AnimatedBuilder(
      animation: _goalController,
      builder: (context, child) {
        final progress = _goalController.value;
        return IgnorePointer(
          child: Stack(children: [
            Container(color: Colors.black.withValues(alpha: 0.4 * (1 - progress))),
            ...List.generate(24, (i) {
              final rand = math.Random(i);
              final dx = rand.nextDouble() * MediaQuery.sizeOf(context).width;
              final dy = MediaQuery.sizeOf(context).height * (1 - progress) -
                  rand.nextDouble() * 200 * progress;
              final size = 6 + rand.nextDouble() * 10;
              final colors = [FCColors.gold, FCColors.accent, FCColors.red, Colors.green, FCColors.blue];
              final color = colors[i % colors.length];
              final rotation = progress * math.pi * 4 * (rand.nextDouble() - 0.5);
              return Positioned(
                left: dx,
                top: dy,
                child: Transform.rotate(
                  angle: rotation,
                  child: Opacity(
                    opacity: (1 - progress).clamp(0.0, 1.0),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(size / 2),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Center(
              child: Opacity(
                opacity: (1 - progress * 1.5).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + progress * 0.4,
                  child: const Text(
                    'GOAL!',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: FCColors.gold,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  static IconData _eventIcon(String type) {
    return switch (type) {
      'GOAL' => Icons.sports_soccer,
      'OWN_GOAL' => Icons.sentiment_dissatisfied,
      'YELLOW_CARD' => Icons.square,
      'RED_CARD' => Icons.square,
      'ASSIST' => Icons.handshake,
      'SAVE' => Icons.back_hand,
      'PENALTY_SCORED' => Icons.adjust,
      'PENALTY_MISSED' => Icons.close,
      _ => Icons.circle,
    };
  }

  static Color _eventColor(String type) {
    return switch (type) {
      'GOAL' => FCColors.gold,
      'OWN_GOAL' => FCColors.red,
      'YELLOW_CARD' => FCColors.amber,
      'RED_CARD' => FCColors.red,
      'ASSIST' => FCColors.blue,
      'SAVE' => Colors.green,
      'PENALTY_SCORED' => FCColors.gold,
      'PENALTY_MISSED' => FCColors.red,
      _ => FCColors.white50,
    };
  }

  static String _eventLabel(String type) {
    return switch (type) {
      'GOAL' => 'Goal',
      'OWN_GOAL' => 'Own Goal',
      'YELLOW_CARD' => 'Yellow Card',
      'RED_CARD' => 'Red Card',
      'ASSIST' => 'Assist',
      'SAVE' => 'Save',
      'PENALTY_SCORED' => 'Penalty Scored',
      'PENALTY_MISSED' => 'Penalty Missed',
      _ => type,
    };
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
