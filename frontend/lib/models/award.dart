import 'package:flutter/material.dart';

class Award {
  final int id;
  final int leagueId;
  final int? seasonId;
  final int? tournamentId;
  final String awardType;
  final String awardTypeDisplay;
  final String customName;
  final String username;
  final String source;
  final String description;
  final String? awardedByName;
  final String awardedAt;

  Award({
    required this.id,
    required this.leagueId,
    this.seasonId,
    this.tournamentId,
    required this.awardType,
    required this.awardTypeDisplay,
    required this.customName,
    required this.username,
    required this.source,
    required this.description,
    this.awardedByName,
    required this.awardedAt,
  });

  factory Award.fromJson(Map<String, dynamic> json) => Award(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    seasonId: json['season'],
    tournamentId: json['tournament'],
    awardType: json['award_type'] ?? '',
    awardTypeDisplay: json['award_type_display'] ?? '',
    customName: json['custom_name'] ?? '',
    username: json['username'] ?? '',
    source: json['source'] ?? 'AUTO',
    description: json['description'] ?? '',
    awardedByName: json['awarded_by'],
    awardedAt: json['awarded_at'] ?? '',
  );

  String get displayName => customName.isNotEmpty ? customName : awardTypeDisplay;

  static const awardIcons = {
    'PLAYER_OF_SEASON': '🏆',
    'GOLDEN_BOOT': '👟',
    'GOLDEN_BALL': '⚽',
    'TOURNAMENT_MVP': '🌟',
    'BEST_DEFENDER': '🛡️',
    'BEST_PERFORMER': '🔥',
    'PLAYER_OF_MONTH': '📅',
    'FAIR_PLAY': '🤝',
    'LEAGUE_CHAMPION': '🥇',
    'TOURNAMENT_CHAMPION': '🏅',
    'RUNNER_UP': '🥈',
    'CUSTOM': '🎖️',
  };

  static const awardColors = {
    'PLAYER_OF_SEASON': 'gold',
    'GOLDEN_BOOT': 'amber',
    'GOLDEN_BALL': 'white',
    'TOURNAMENT_MVP': 'purple',
    'BEST_DEFENDER': 'blue',
    'BEST_PERFORMER': 'red',
    'PLAYER_OF_MONTH': 'green',
    'FAIR_PLAY': 'teal',
    'LEAGUE_CHAMPION': 'gold',
    'TOURNAMENT_CHAMPION': 'amber',
    'RUNNER_UP': 'silver',
    'CUSTOM': 'cyan',
  };
}

class LeagueRecord {
  final int id;
  final int leagueId;
  final String recordType;
  final String recordTypeDisplay;
  final String username;
  final double value;
  final int? matchId;
  final String achievedAt;
  final bool isCurrent;
  final Map<String, dynamic> metadata;

  LeagueRecord({
    required this.id,
    required this.leagueId,
    required this.recordType,
    required this.recordTypeDisplay,
    required this.username,
    required this.value,
    this.matchId,
    required this.achievedAt,
    required this.isCurrent,
    required this.metadata,
  });

  factory LeagueRecord.fromJson(Map<String, dynamic> json) => LeagueRecord(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    recordType: json['record_type'] ?? '',
    recordTypeDisplay: json['record_type_display'] ?? '',
    username: json['username'] ?? '',
    value: (json['value'] ?? 0).toDouble(),
    matchId: json['match'],
    achievedAt: json['achieved_at'] ?? '',
    isCurrent: json['is_current'] ?? true,
    metadata: json['metadata'] ?? {},
  );

  static const recordIcons = {
    'HIGHEST_RATING': Icons.star,
    'MOST_GOALS': Icons.sports_soccer,
    'MOST_WINS': Icons.emoji_events,
    'LONGEST_WIN_STREAK': Icons.local_fire_department,
    'MOST_GOALS_IN_MATCH': Icons.bolt,
    'MOST_TOURNAMENT_WINS': Icons.military_tech,
    'BEST_WIN_RATE': Icons.percent,
    'BIGGEST_WINNING_MARGIN': Icons.trending_up,
    'MOST_CLEAN_SHEETS': Icons.shield,
  };
}