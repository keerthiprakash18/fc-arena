import 'package:flutter/material.dart';

/// Statistics for a team, aggregated from VERIFIED matches only.
///
/// The API returns `null` for a team that has never had a match verified, so
/// every consumer must handle the "no data yet" case rather than inventing
/// numbers. [TeamStatistics.empty] exists for exactly that purpose.
class TeamStatistics {
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int goalDifference;
  final int cleanSheets;
  final int points;
  final double winRate;
  final double goalsPerMatch;
  final List<String> form;
  final int currentWinStreak;
  final int bestWinStreak;

  TeamStatistics({
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsScored,
    required this.goalsConceded,
    required this.goalDifference,
    required this.cleanSheets,
    required this.points,
    required this.winRate,
    required this.goalsPerMatch,
    required this.form,
    required this.currentWinStreak,
    required this.bestWinStreak,
  });

  /// A genuine zero state — no matches played yet. Not placeholder data.
  static TeamStatistics empty() => TeamStatistics(
        matchesPlayed: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsScored: 0,
        goalsConceded: 0,
        goalDifference: 0,
        cleanSheets: 0,
        points: 0,
        winRate: 0,
        goalsPerMatch: 0,
        form: const [],
        currentWinStreak: 0,
        bestWinStreak: 0,
      );

  bool get hasPlayed => matchesPlayed > 0;

  factory TeamStatistics.fromJson(Map<String, dynamic> json) => TeamStatistics(
        matchesPlayed: _int(json['matches_played']),
        wins: _int(json['wins']),
        draws: _int(json['draws']),
        losses: _int(json['losses']),
        goalsScored: _int(json['goals_scored']),
        goalsConceded: _int(json['goals_conceded']),
        goalDifference: _int(json['goal_difference']),
        cleanSheets: _int(json['clean_sheets']),
        points: _int(json['points']),
        winRate: _double(json['win_rate']),
        goalsPerMatch: _double(json['goals_per_match']),
        form: (json['form'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        currentWinStreak: _int(json['current_win_streak']),
        bestWinStreak: _int(json['best_win_streak']),
      );

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  static double _double(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

class TeamMember {
  final int id;
  final int? userId;
  final String username;
  final String displayName;
  final String? profilePhoto;
  final String role;
  final int? jerseyNumber;
  final String position;
  final bool isActive;

  TeamMember({
    required this.id,
    this.userId,
    required this.username,
    required this.displayName,
    this.profilePhoto,
    required this.role,
    this.jerseyNumber,
    required this.position,
    required this.isActive,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user'] as num?)?.toInt(),
        username: json['username'] ?? '',
        displayName: json['display_name'] ?? json['username'] ?? '',
        profilePhoto: json['profile_photo'],
        role: json['role'] ?? 'PLAYER',
        jerseyNumber: (json['jersey_number'] as num?)?.toInt(),
        position: json['position'] ?? '',
        isActive: json['is_active'] ?? true,
      );

  bool get isCaptain => role == 'CAPTAIN';
  bool get isCoach => role == 'COACH';

  Color get roleColor {
    switch (role) {
      case 'CAPTAIN': return const Color(0xFFF5C542);
      case 'COACH': return const Color(0xFF9B59B6);
      case 'SUBSTITUTE': return const Color(0xFF3498DB);
      default: return const Color(0xFF2ECC71);
    }
  }
}

class Team {
  final int id;
  final int leagueId;
  final String name;
  final String shortName;
  final String slug;
  final String description;
  final String game;
  final String? logoUrl;
  final String? bannerUrl;
  final int? captainId;
  final String? captainName;
  final int? managerId;
  final String? managerName;
  final Map<String, dynamic> socialLinks;
  final bool isActive;
  final int memberCount;
  final TeamStatistics? statistics;
  final List<TeamMember> members;

  Team({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.shortName,
    required this.slug,
    required this.description,
    required this.game,
    this.logoUrl,
    this.bannerUrl,
    this.captainId,
    this.captainName,
    this.managerId,
    this.managerName,
    this.socialLinks = const {},
    required this.isActive,
    required this.memberCount,
    this.statistics,
    this.members = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: (json['id'] as num?)?.toInt() ?? 0,
        leagueId: (json['league'] as num?)?.toInt() ?? 0,
        name: json['name'] ?? '',
        shortName: json['short_name'] ?? '',
        slug: json['slug'] ?? '',
        description: json['description'] ?? '',
        game: json['game'] ?? '',
        logoUrl: json['logo_url'],
        bannerUrl: json['banner_url'],
        captainId: (json['captain'] as num?)?.toInt(),
        captainName: json['captain_name'],
        managerId: (json['manager'] as num?)?.toInt(),
        managerName: json['manager_name'],
        socialLinks: (json['social_links'] as Map?)?.cast<String, dynamic>() ?? const {},
        isActive: json['is_active'] ?? true,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        statistics: json['statistics'] != null
            ? TeamStatistics.fromJson((json['statistics'] as Map).cast<String, dynamic>())
            : null,
        members: (json['members'] as List?)
                ?.map((m) => TeamMember.fromJson((m as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  /// Stats with a real zero state, so callers never have to null-check.
  TeamStatistics get stats => statistics ?? TeamStatistics.empty();

  /// Two or three letters for tight layouts.
  String get initials {
    if (shortName.isNotEmpty) return shortName.toUpperCase();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isEmpty ? '?' : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

/// One row of the league team table.
class TeamStanding {
  final int rank;
  final int teamId;
  final String name;
  final String shortName;
  final String? logoUrl;
  final TeamStatistics statistics;

  TeamStanding({
    required this.rank,
    required this.teamId,
    required this.name,
    required this.shortName,
    this.logoUrl,
    required this.statistics,
  });

  factory TeamStanding.fromJson(Map<String, dynamic> json) => TeamStanding(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        teamId: (json['team_id'] as num?)?.toInt() ?? 0,
        name: json['name'] ?? '',
        shortName: json['short_name'] ?? '',
        logoUrl: json['logo_url'],
        statistics: json['statistics'] != null
            ? TeamStatistics.fromJson((json['statistics'] as Map).cast<String, dynamic>())
            : TeamStatistics.empty(),
      );

  Color get rankColor {
    switch (rank) {
      case 1: return const Color(0xFFF5C542);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return const Color(0x80FFFFFF);
    }
  }
}
