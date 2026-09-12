import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api.dart';
import '../models/match.dart';
import '../models/team.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fc_animations.dart';
import 'match_detail_screen.dart';

/// A team's public profile: identity, aggregate statistics, form, roster and
/// its recent fixtures.
///
/// Every figure is derived from verified matches. A team with none shows a
/// zero state and an explicit note rather than sample numbers.
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key, required this.leagueId, required this.teamId});

  final int leagueId;
  final int teamId;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final _api = ApiService(apiClient);

  Team? _team;
  List<Match> _matches = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final team = await _api.getTeam(widget.leagueId, widget.teamId);

      // The team payload may not carry statistics yet; fetch the dedicated
      // endpoint so a freshly created team still renders its zero state.
      if (team.statistics == null) {
        try {
          final stats = await _api.getTeamStatistics(widget.leagueId, widget.teamId);
          if (stats != null) _team = _withStats(team, stats);
        } catch (_) {}
      }

      List<Match> matches = [];
      try {
        final all = await _api.getLeagueMatches(widget.leagueId);
        matches = all
            .where((m) => m.isTeamMatch &&
                (m.homeTeamId == widget.teamId || m.awayTeamId == widget.teamId))
            .toList()
          ..sort((a, b) => (b.scheduledAt ?? b.createdAt).compareTo(a.scheduledAt ?? a.createdAt));
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _team = _team ?? team;
        _matches = matches;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// Returns a copy of [team] with [stats] attached.
  Team _withStats(Team team, TeamStatistics stats) => Team(
        id: team.id,
        leagueId: team.leagueId,
        name: team.name,
        shortName: team.shortName,
        slug: team.slug,
        description: team.description,
        game: team.game,
        logoUrl: team.logoUrl,
        bannerUrl: team.bannerUrl,
        captainId: team.captainId,
        captainName: team.captainName,
        managerId: team.managerId,
        managerName: team.managerName,
        socialLinks: team.socialLinks,
        isActive: team.isActive,
        memberCount: team.memberCount,
        statistics: stats,
        members: team.members,
      );

  Future<void> _pickImage(String field) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final mime = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final updated = await _api.uploadTeamImage(
        widget.leagueId, widget.teamId,
        field: field,
        filePath: picked.path,
        fileName: picked.name,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() => _team = updated);
      _toast('${field == 'logo' ? 'Logo' : 'Banner'} updated');
    } catch (e) {
      _toast('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recompute() async {
    setState(() => _busy = true);
    try {
      final stats = await _api.recomputeTeamStatistics(widget.leagueId, widget.teamId);
      if (!mounted) return;
      setState(() => _team = _withStats(_team!, stats));
      _toast('Statistics recomputed from verified matches');
    } catch (e) {
      _toast('Could not recompute: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? FCColors.red : FCColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FCColors.accent))
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : _team == null
                  ? const Center(child: Text('Team not found', style: TextStyle(color: Colors.white54)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: FCColors.accent,
                      child: CustomScrollView(
                        slivers: [
                          _buildHeader(),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                if (_team!.description.isNotEmpty) ...[
                                  Text(
                                    _team!.description,
                                    style: TextStyle(fontSize: 13, height: 1.5, color: FCColors.white50),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                _buildStatisticsSection(),
                                const SizedBox(height: 20),
                                _buildRosterSection(),
                                const SizedBox(height: 20),
                                _buildMatchesSection(),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final team = _team!;
    final hasBanner = team.bannerUrl != null && team.bannerUrl!.isNotEmpty;

    return SliverAppBar(
      pinned: true,
      expandedHeight: hasBanner ? 200 : 150,
      backgroundColor: FCColors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: FCColors.white70),
          onSelected: (v) {
            if (v == 'logo') _pickImage('logo');
            if (v == 'banner') _pickImage('banner');
            if (v == 'recompute') _recompute();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'logo', child: Row(children: [
              Icon(Icons.image_outlined, size: 18, color: FCColors.white70),
              SizedBox(width: 10), Text('Change logo'),
            ])),
            PopupMenuItem(value: 'banner', child: Row(children: [
              Icon(Icons.wallpaper_outlined, size: 18, color: FCColors.white70),
              SizedBox(width: 10), Text('Change banner'),
            ])),
            PopupMenuItem(value: 'recompute', child: Row(children: [
              Icon(Icons.calculate_outlined, size: 18, color: FCColors.white70),
              SizedBox(width: 10), Text('Recompute stats'),
            ])),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasBanner)
              Image.network(
                team.bannerUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              )
            else
              Container(decoration: const BoxDecoration(gradient: FCGradients.hero)),
            // Darken the bottom so the crest and name stay legible.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    FCColors.pitch.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 56, height: 56,
                      child: Center(child: CircularProgressIndicator(color: FCColors.accent, strokeWidth: 2)),
                    )
                  else
                    TeamLogo(logoUrl: team.logoUrl, initials: team.initials, size: 56, radius: 16),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (team.game.isNotEmpty) ...[
                              StatusBadge(text: team.game, color: FCColors.blue, small: true),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              '${team.memberCount} player${team.memberCount == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11.5, color: FCColors.white50),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Statistics ────────────────────────────────────────────────────────────
  Widget _buildStatisticsSection() {
    final s = _team!.stats;

    if (!s.hasPlayed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FCSectionHeader(title: 'STATISTICS'),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.insights_outlined, size: 28, color: FCColors.white15),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No verified matches yet',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: FCColors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        'Statistics are calculated from matches that have been '
                        'verified. This team has none so far.',
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: FCColors.white30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Cumulative points across verified matches, oldest → newest.
    final pointsTrend = _pointsTrend();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FCSectionHeader(title: 'STATISTICS'),
        const SizedBox(height: 12),
        Row(
          children: [
            ProgressRing(
              percent: s.winRate,
              size: 86,
              strokeWidth: 7,
              color: FCColors.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter(
                    value: s.winRate,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                    formatter: (v) => '${v.toInt()}%',
                  ),
                  Text('WIN RATE', style: TextStyle(fontSize: 8, color: FCColors.white30, letterSpacing: 0.6)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _recordLine('Played', s.matchesPlayed, FCColors.white70),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _pill('${s.wins} W', FCColors.accent),
                      const SizedBox(width: 6),
                      _pill('${s.draws} D', FCColors.amber),
                      const SizedBox(width: 6),
                      _pill('${s.losses} L', FCColors.red),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Form', style: TextStyle(fontSize: 11, color: FCColors.white30)),
                      const SizedBox(width: 10),
                      Flexible(child: FormStrip(form: s.form, size: 20)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.85,
          children: [
            StatTile(label: 'Points', value: s.points, icon: Icons.stars_outlined, color: FCColors.gold),
            StatTile(label: 'Goal Diff', value: s.goalDifference, icon: Icons.swap_vert, color: FCColors.blue),
            StatTile(label: 'Scored', value: s.goalsScored, icon: Icons.sports_soccer, color: FCColors.accent),
            StatTile(label: 'Conceded', value: s.goalsConceded, icon: Icons.shield_moon_outlined, color: FCColors.red),
            StatTile(label: 'Clean Sheets', value: s.cleanSheets, icon: Icons.lock_outline, color: FCColors.teal),
            StatTile(
              label: 'Goals / Match',
              value: s.goalsPerMatch,
              icon: Icons.trending_up,
              color: FCColors.purple,
              decimals: 2,
            ),
          ],
        ),
        if (s.currentWinStreak > 1 || s.bestWinStreak > 1) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderColor: FCColors.gold.withValues(alpha: 0.25),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, size: 22, color: FCColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.currentWinStreak > 1
                            ? '${s.currentWinStreak}-match winning streak'
                            : 'Best streak: ${s.bestWinStreak} wins',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Longest run this season: ${s.bestWinStreak}',
                        style: TextStyle(fontSize: 11, color: FCColors.white50),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const FCSectionHeader(title: 'POINTS PROGRESS'),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SparkLine(
                values: pointsTrend,
                color: FCColors.accent,
                height: 64,
                emptyLabel: 'Play at least two verified matches to see a trend',
              ),
              if (pointsTrend.length >= 2) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('First match', style: TextStyle(fontSize: 9.5, color: FCColors.white30)),
                    Text('Latest (${pointsTrend.last} pts)',
                        style: TextStyle(fontSize: 9.5, color: FCColors.white30)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordLine(String label, int value, Color color) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: FCColors.white50)),
        const SizedBox(width: 8),
        AnimatedCounter(
          value: value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  /// Cumulative league points after each verified match, oldest first.
  List<num> _pointsTrend() {
    final played = _matches
        .where((m) => m.isVerified && m.hasScore)
        .toList()
      ..sort((a, b) => (a.scheduledAt ?? a.createdAt).compareTo(b.scheduledAt ?? b.createdAt));

    var total = 0;
    final trend = <num>[];
    for (final m in played) {
      final isHome = m.homeTeamId == widget.teamId;
      final myScore = isHome ? m.homeScore! : m.awayScore!;
      final theirScore = isHome ? m.awayScore! : m.homeScore!;
      if (myScore > theirScore) {
        total += 3;
      } else if (myScore == theirScore) {
        total += 1;
      }
      trend.add(total);
    }
    return trend;
  }

  // ── Roster ────────────────────────────────────────────────────────────────
  Widget _buildRosterSection() {
    final members = _team!.members.where((m) => m.isActive).toList()
      ..sort((a, b) {
        // Captain first, then by jersey number, then alphabetically.
        if (a.isCaptain != b.isCaptain) return a.isCaptain ? -1 : 1;
        final an = a.jerseyNumber ?? 999;
        final bn = b.jerseyNumber ?? 999;
        if (an != bn) return an.compareTo(bn);
        return a.displayName.compareTo(b.displayName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FCSectionHeader(
          title: 'SQUAD',
          trailing: Text('${members.length}', style: TextStyle(fontSize: 12, color: FCColors.white30)),
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.person_add_alt, size: 26, color: FCColors.white15),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No players on the roster',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: FCColors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        'Add players from your league to build the squad.',
                        style: TextStyle(fontSize: 11.5, color: FCColors.white30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...members.map(_memberTile),
      ],
    );
  }

  Widget _memberTile(TeamMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FCColors.surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: member.roleColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              member.jerseyNumber?.toString() ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: member.jerseyNumber != null ? FCColors.white70 : FCColors.white15,
              ),
            ),
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: member.roleColor.withValues(alpha: 0.18),
            child: Text(
              member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: member.roleColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.position.isNotEmpty)
                  Text(member.position, style: TextStyle(fontSize: 11, color: FCColors.white30)),
              ],
            ),
          ),
          StatusBadge(text: member.role, color: member.roleColor, small: true),
        ],
      ),
    );
  }

  // ── Matches ───────────────────────────────────────────────────────────────
  Widget _buildMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FCSectionHeader(
          title: 'RECENT MATCHES',
          trailing: Text('${_matches.length}', style: TextStyle(fontSize: 12, color: FCColors.white30)),
        ),
        const SizedBox(height: 12),
        if (_matches.isEmpty)
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, size: 26, color: FCColors.white15),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No fixtures scheduled for this team yet.',
                    style: TextStyle(fontSize: 12.5, color: FCColors.white50),
                  ),
                ),
              ],
            ),
          )
        else
          ..._matches.take(10).map(_matchRow),
      ],
    );
  }

  Widget _matchRow(Match m) {
    final isHome = m.homeTeamId == widget.teamId;
    final outcome = m.hasScore
        ? (isHome ? m.outcome : -m.outcome)
        : 0;
    final outcomeColor = !m.hasScore
        ? FCColors.white30
        : outcome > 0
            ? FCColors.accent
            : outcome < 0
                ? FCColors.red
                : FCColors.amber;
    final outcomeLabel = !m.hasScore ? '—' : outcome > 0 ? 'W' : outcome < 0 ? 'L' : 'D';
    final opponent = isHome ? m.awayName : m.homeName;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: m.id),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FCColors.surfaceCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FCColors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: outcomeColor.withValues(alpha: 0.35)),
              ),
              alignment: Alignment.center,
              child: Text(outcomeLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: outcomeColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(isHome ? 'vs ' : 'at ',
                          style: TextStyle(fontSize: 11, color: FCColors.white30)),
                      Flexible(
                        child: Text(opponent,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(m.scheduledAt ?? m.createdAt),
                    style: TextStyle(fontSize: 10.5, color: FCColors.white30),
                  ),
                ],
              ),
            ),
            Text(
              m.scoreDisplay,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: m.hasScore ? Colors.white : FCColors.white30,
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(text: m.statusLabel, color: m.statusColor, small: true),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} · $h:$min $ampm';
  }
}
