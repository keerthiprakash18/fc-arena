class LeagueOverview {
  final Map<String, dynamic> league;
  final Map<String, dynamic> counts;
  final Map<String, dynamic> performance;
  final Map<String, dynamic>? leaders;

  LeagueOverview({
    required this.league,
    required this.counts,
    required this.performance,
    this.leaders,
  });

  factory LeagueOverview.fromJson(Map<String, dynamic> json) => LeagueOverview(
    league: json['league'] ?? {},
    counts: json['counts'] ?? {},
    performance: json['performance'] ?? {},
    leaders: json['leaders'],
  );

  String get leagueName => league['name'] ?? '';
  String get leagueCode => league['code'] ?? '';
  int get membersCount => counts['members'] ?? 0;
  int get tournamentsCount => counts['tournaments'] ?? 0;
  int get matchesTotal => counts['matches_total'] ?? 0;
  int get matchesVerified => counts['matches_verified'] ?? 0;
  int get pendingReviews => counts['pending_verification_reviews'] ?? 0;
  int get openDisputes => counts['open_disputes'] ?? 0;
  int get totalGoals => performance['total_goals'] ?? 0;
  double get avgGoalsPerMatch => (performance['avg_goals_per_verified_match'] ?? 0).toDouble();
  String get leaderUsername => leaders?['standings_leader']?['username'] ?? '-';
  int get leaderPoints => leaders?['standings_leader']?['points'] ?? 0;
  String get topScorerUsername => leaders?['top_scorer']?['username'] ?? '-';
  int get topScorerGoals => leaders?['top_scorer']?['goals'] ?? 0;
}

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id: id, type: type, title: title, message: message,
    isRead: isRead ?? this.isRead, createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'] ?? 0,
    type: json['notification_type'] ?? '',
    title: json['title'] ?? '',
    message: json['message'] ?? '',
    isRead: json['is_read'] ?? false,
    createdAt: json['created_at'] ?? '',
  );
}

class VerificationTask {
  final int id;
  final int matchId;
  final String status;
  final String? aiProvider;
  final dynamic aiConfidenceScore;
  final dynamic aiExtractedData;
  final String? adminNotes;
  final String? verifiedByName;
  final String? evidenceFile;
  final List<ExtractionResultItem> results;
  final String createdAt;

  VerificationTask({
    required this.id,
    required this.matchId,
    required this.status,
    this.aiProvider,
    this.aiConfidenceScore,
    this.aiExtractedData,
    this.adminNotes,
    this.verifiedByName,
    this.evidenceFile,
    this.results = const [],
    required this.createdAt,
  });

  factory VerificationTask.fromJson(Map<String, dynamic> json) => VerificationTask(
    id: json['id'] ?? 0,
    matchId: json['match'] ?? 0,
    status: json['status'] ?? '',
    aiProvider: json['ai_provider'],
    aiConfidenceScore: json['ai_confidence_score'],
    aiExtractedData: json['ai_extracted_data'],
    adminNotes: json['admin_notes'],
    verifiedByName: json['verified_by_name'],
    evidenceFile: json['evidence_file'],
    results: (json['results'] as List? ?? [])
        .map((r) => ExtractionResultItem.fromJson(r))
        .toList(),
    createdAt: json['created_at'] ?? '',
  );
}

class ExtractionResultItem {
  final int id;
  final String fieldName;
  final String fieldValue;
  final double? confidence;
  final String? sourceRegion;
  final bool isReliable;

  ExtractionResultItem({
    required this.id,
    required this.fieldName,
    required this.fieldValue,
    this.confidence,
    this.sourceRegion,
    this.isReliable = false,
  });

  factory ExtractionResultItem.fromJson(Map<String, dynamic> json) => ExtractionResultItem(
    id: json['id'] ?? 0,
    fieldName: json['field_name'] ?? '',
    fieldValue: json['field_value'] ?? '',
    confidence: (json['confidence'] as num?)?.toDouble(),
    sourceRegion: json['source_region'],
    isReliable: json['is_reliable'] ?? false,
  );
}

class AdminReviewItem {
  final int taskId;
  final int matchId;
  final String homeUsername;
  final String awayUsername;
  final double? confidence;
  final String status;
  final String createdAt;

  AdminReviewItem({
    required this.taskId,
    required this.matchId,
    required this.homeUsername,
    required this.awayUsername,
    this.confidence,
    required this.status,
    required this.createdAt,
  });

  factory AdminReviewItem.fromJson(Map<String, dynamic> json) => AdminReviewItem(
    taskId: json['task_id'] ?? 0,
    matchId: json['match_id'] ?? 0,
    homeUsername: json['home_user'] ?? '',
    awayUsername: json['away_user'] ?? '',
    confidence: (json['confidence'] as num?)?.toDouble(),
    status: json['status'] ?? '',
    createdAt: json['created_at'] ?? '',
  );
}

class PendingReviewsData {
  final List<AdminReviewItem> reviews;
  final List<Map<String, dynamic>> disputes;

  PendingReviewsData({required this.reviews, required this.disputes});
}