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

  String get scoreDisplay {
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    }
    return 'vs';
  }

  Color get statusColor {
    switch (status) {
      case 'VERIFIED': return Colors.green;
      case 'SCHEDULED': return Colors.blue;
      case 'AWAITING_RESULT': return Colors.orange;
      case 'EVIDENCE_SUBMITTED': return Colors.amber;
      case 'ADMIN_REVIEW': return Colors.purple;
      case 'REJECTED': return Colors.red;
      case 'DISPUTED': return Colors.red.shade700;
      default: return Colors.grey;
    }
  }
}