import 'package:flutter/material.dart';

class Match {
  final int id;
  final int leagueId;
  final String? leagueName;
  final int? tournamentId;
  final String? homeUsername;
  final String? awayUsername;
  final int? homeUserId;
  final int? awayUserId;
  // Team-based fixtures leave the user fields null and populate these instead.
  final int? homeTeamId;
  final int? awayTeamId;
  final String? homeTeamName;
  final String? awayTeamName;
  final String? homeTeamShortName;
  final String? awayTeamShortName;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final String? homeDisplay;
  final String? awayDisplay;
  final bool isTeamMatch;
  final String venue;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final String? scheduledAt;
  final String? playedAt;
  final String? verifiedAt;
  final String createdAt;

  Match({
    required this.id,
    required this.leagueId,
    this.leagueName,
    this.tournamentId,
    this.homeUsername,
    this.awayUsername,
    this.homeUserId,
    this.awayUserId,
    this.homeTeamId,
    this.awayTeamId,
    this.homeTeamName,
    this.awayTeamName,
    this.homeTeamShortName,
    this.awayTeamShortName,
    this.homeTeamLogo,
    this.awayTeamLogo,
    this.homeDisplay,
    this.awayDisplay,
    this.isTeamMatch = false,
    this.venue = '',
    this.homeScore,
    this.awayScore,
    required this.status,
    this.scheduledAt,
    this.playedAt,
    this.verifiedAt,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    leagueName: json['league_name'],
    tournamentId: json['tournament'],
    homeUsername: json['home_username'],
    awayUsername: json['away_username'],
    homeUserId: json['home_user'],
    awayUserId: json['away_user'],
    homeTeamId: json['home_team'],
    awayTeamId: json['away_team'],
    homeTeamName: json['home_team_name'],
    awayTeamName: json['away_team_name'],
    homeTeamShortName: json['home_team_short_name'],
    awayTeamShortName: json['away_team_short_name'],
    homeTeamLogo: json['home_team_logo'],
    awayTeamLogo: json['away_team_logo'],
    homeDisplay: json['home_display'],
    awayDisplay: json['away_display'],
    isTeamMatch: json['is_team_match'] ?? false,
    venue: json['venue'] ?? '',
    homeScore: json['home_score'],
    awayScore: json['away_score'],
    status: json['status'] ?? 'SCHEDULED',
    scheduledAt: json['scheduled_at'],
    playedAt: json['played_at'],
    verifiedAt: json['verified_at'],
    createdAt: json['created_at'] ?? '',
  );

  bool get isVerified => status == 'VERIFIED';
  bool get isScheduled => status == 'SCHEDULED';
  bool get canSubmitResult => status == 'AWAITING_RESULT';
  bool get canUploadEvidence => ['AWAITING_RESULT', 'EVIDENCE_SUBMITTED'].contains(status);
  bool get isComplete => isVerified || status == 'REJECTED' || status == 'DISPUTED';

  /// The name to show for each side, whichever kind of fixture this is.
  /// Falls back through display name → username → team name → TBD.
  String get homeName => homeDisplay ?? homeUsername ?? homeTeamName ?? 'TBD';
  String get awayName => awayDisplay ?? awayUsername ?? awayTeamName ?? 'TBD';

  /// Short label for tight layouts (scoreboards, compact lists).
  String get homeShort =>
      homeTeamShortName?.isNotEmpty == true ? homeTeamShortName! : homeName;
  String get awayShort =>
      awayTeamShortName?.isNotEmpty == true ? awayTeamShortName! : awayName;

  String get scoreDisplay {
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    }
    return 'vs';
  }

  /// True once a winner can be read off the score.
  bool get hasScore => homeScore != null && awayScore != null;

  /// 1 = home win, -1 = away win, 0 = draw / no score.
  int get outcome {
    if (!hasScore) return 0;
    if (homeScore! > awayScore!) return 1;
    if (awayScore! > homeScore!) return -1;
    return 0;
  }

  Color get statusColor {
    switch (status) {
      case 'VERIFIED': return Colors.green;
      case 'SCHEDULED': return Colors.blue;
      case 'AWAITING_RESULT': return Colors.orange;
      case 'EVIDENCE_SUBMITTED': return Colors.amber;
      case 'AI_PROCESSING': return Colors.cyan;
      case 'ADMIN_REVIEW': return Colors.purple;
      case 'REJECTED': return Colors.red;
      case 'DISPUTED': return Colors.red.shade700;
      case 'CANCELLED': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'SCHEDULED': return 'Scheduled';
      case 'AWAITING_RESULT': return 'Awaiting Result';
      case 'EVIDENCE_SUBMITTED': return 'Evidence In';
      case 'AI_PROCESSING': return 'Processing';
      case 'ADMIN_REVIEW': return 'In Review';
      case 'DISPUTED': return 'Disputed';
      case 'VERIFIED': return 'Verified';
      case 'REJECTED': return 'Rejected';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }
}