class DisputeComment {
  final int id;
  final String username;
  final String comment;
  final String createdAt;

  DisputeComment({
    required this.id,
    required this.username,
    required this.comment,
    required this.createdAt,
  });

  factory DisputeComment.fromJson(Map<String, dynamic> json) => DisputeComment(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    comment: json['comment'] ?? '',
    createdAt: json['created_at'] ?? '',
  );
}

class Dispute {
  final int id;
  final int leagueId;
  final int matchId;
  final String reason;
  final String description;
  final String status;
  final String? resolution;
  final String? raisedByName;
  final String? resolvedByName;
  final String? resolutionNotes;
  final List<DisputeComment> comments;
  final String createdAt;

  Dispute({
    required this.id,
    required this.leagueId,
    required this.matchId,
    required this.reason,
    required this.description,
    required this.status,
    this.resolution,
    this.raisedByName,
    this.resolvedByName,
    this.resolutionNotes,
    this.comments = const [],
    required this.createdAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    matchId: json['match'] ?? 0,
    reason: json['reason'] ?? '',
    description: json['description'] ?? '',
    status: json['status'] ?? 'OPEN',
    resolution: json['resolution'],
    raisedByName: json['raised_by_name'],
    resolvedByName: json['resolved_by_name'],
    resolutionNotes: json['resolution_notes'],
    comments: (json['comments'] as List? ?? [])
        .map((c) => DisputeComment.fromJson(c))
        .toList(),
    createdAt: json['created_at'] ?? '',
  );

  bool get isOpen => status == 'OPEN';

  String get reasonLabel {
    switch (reason) {
      case 'WRONG_SCORE': return 'Wrong Score';
      case 'WRONG_OPPONENT': return 'Wrong Opponent';
      case 'INVALID_SCREENSHOT': return 'Invalid Screenshot';
      case 'INCORRECT_STATISTICS': return 'Incorrect Statistics';
      case 'CHEATING': return 'Cheating';
      case 'OTHER': return 'Other';
      default: return reason;
    }
  }

  String get resolutionLabel {
    switch (resolution) {
      case 'ACCEPTED': return 'Accepted';
      case 'REJECTED': return 'Rejected';
      case 'CORRECTED': return 'Corrected';
      default: return '';
    }
  }
}

class DisputeCreateData {
  final int matchId;
  final String reason;
  final String description;
  DisputeCreateData({required this.matchId, required this.reason, required this.description});
}