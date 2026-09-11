// ============================================================
// FC ARENA — LEAGUE / TOURNAMENT OVERVIEW
// ============================================================

class LeagueOverview {
  final Map<String, dynamic> league;
  final Map<String, dynamic> counts;
  final Map<String, dynamic> performance;
  final Map<String, dynamic>? leaders;

  const LeagueOverview({
    required this.league,
    required this.counts,
    required this.performance,
    this.leaders,
  });

  factory LeagueOverview.fromJson(Map<String, dynamic> json) {
    return LeagueOverview(
      league: _map(json['league']),
      counts: _map(json['counts']),
      performance: _map(json['performance']),
      leaders: json['leaders'] is Map
          ? Map<String, dynamic>.from(json['leaders'])
          : null,
    );
  }

  String get leagueName => _string(league['name']);
  String get leagueCode => _string(league['code']);

  int get membersCount => _int(counts['members']);
  int get tournamentsCount => _int(counts['tournaments']);
  int get matchesTotal => _int(counts['matches_total']);
  int get matchesVerified => _int(counts['matches_verified']);

  int get pendingReviews =>
      _int(counts['pending_verification_reviews']);

  int get openDisputes =>
      _int(counts['open_disputes']);

  int get totalGoals =>
      _int(performance['total_goals']);

  double get avgGoalsPerMatch =>
      _double(performance['avg_goals_per_verified_match']);

  String get leaderUsername =>
      _nestedString(leaders, 'standings_leader', 'username', '-');

  int get leaderPoints =>
      _nestedInt(leaders, 'standings_leader', 'points');

  String get topScorerUsername =>
      _nestedString(leaders, 'top_scorer', 'username', '-');

  int get topScorerGoals =>
      _nestedInt(leaders, 'top_scorer', 'goals');
}


// ============================================================
// FC ARENA — NOTIFICATIONS
// ============================================================

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: _int(json['id']),
      type: _string(json['notification_type']),
      title: _string(json['title']),
      message: _string(json['message']),
      isRead: _bool(json['is_read']),
      createdAt: _string(json['created_at']),
    );
  }
}


// ============================================================
// FC ARENA — AI VERIFICATION TASK
// ============================================================

class VerificationTask {
  final int id;
  final int matchId;
  final String status;

  final String? aiProvider;
  final double? aiConfidenceScore;

  final dynamic aiExtractedData;

  final String? adminNotes;
  final String? verifiedByName;
  final String? evidenceFile;

  final List<ExtractionResultItem> results;

  final String createdAt;

  const VerificationTask({
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

  factory VerificationTask.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];

    return VerificationTask(
      id: _int(json['id']),
      matchId: _int(json['match'] ?? json['match_id']),
      status: _string(json['status']),

      aiProvider: json['ai_provider']?.toString(),

      aiConfidenceScore:
          _nullableDouble(json['ai_confidence_score']),

      aiExtractedData:
          json['ai_extracted_data'],

      adminNotes:
          json['admin_notes']?.toString(),

      verifiedByName:
          json['verified_by_name']?.toString(),

      evidenceFile:
          json['evidence_file']?.toString(),

      results: rawResults is List
          ? rawResults
              .whereType<Map>()
              .map(
                (item) => ExtractionResultItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],

      createdAt: _string(json['created_at']),
    );
  }
}


// ============================================================
// FC ARENA — AI EXTRACTION RESULT
// ============================================================

class ExtractionResultItem {
  final int id;
  final String fieldName;
  final String fieldValue;

  final double? confidence;

  final String? sourceRegion;

  final bool isReliable;

  const ExtractionResultItem({
    required this.id,
    required this.fieldName,
    required this.fieldValue,
    this.confidence,
    this.sourceRegion,
    this.isReliable = false,
  });

  factory ExtractionResultItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExtractionResultItem(
      id: _int(json['id']),

      fieldName:
          _string(json['field_name']),

      fieldValue:
          _string(json['field_value']),

      confidence:
          _nullableDouble(json['confidence']),

      sourceRegion:
          json['source_region']?.toString(),

      isReliable:
          _bool(json['is_reliable']),
    );
  }
}


// ============================================================
// FC ARENA — ADMIN REVIEW ITEM
// ============================================================

class AdminReviewItem {
  final int taskId;
  final int matchId;

  final String homeUsername;
  final String awayUsername;

  final double? confidence;

  final String status;
  final String createdAt;

  const AdminReviewItem({
    required this.taskId,
    required this.matchId,
    required this.homeUsername,
    required this.awayUsername,
    this.confidence,
    required this.status,
    required this.createdAt,
  });

  factory AdminReviewItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminReviewItem(
      taskId: _int(json['task_id']),
      matchId: _int(json['match_id']),

      homeUsername:
          _string(json['home_user']),

      awayUsername:
          _string(json['away_user']),

      confidence:
          _nullableDouble(json['confidence']),

      status:
          _string(json['status']),

      createdAt:
          _string(json['created_at']),
    );
  }
}


// ============================================================
// FC ARENA — PENDING REVIEWS
// ============================================================

class PendingReviewsData {
  final List<AdminReviewItem> reviews;
  final List<Map<String, dynamic>> disputes;

  const PendingReviewsData({
    required this.reviews,
    required this.disputes,
  });

  factory PendingReviewsData.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawReviews = json['reviews'];
    final rawDisputes = json['disputes'];

    return PendingReviewsData(
      reviews: rawReviews is List
          ? rawReviews
              .whereType<Map>()
              .map(
                (item) => AdminReviewItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],

      disputes: rawDisputes is List
          ? rawDisputes
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList()
          : const [],
    );
  }
}


// ============================================================
// FC ARENA — SAFE JSON HELPERS
// ============================================================

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}


String _string(dynamic value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }

  return value.toString();
}


int _int(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? fallback;
}


double _double(dynamic value, [double fallback = 0.0]) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}


double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}


bool _bool(dynamic value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.toLowerCase().trim();

    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
  }

  return fallback;
}


String _nestedString(
  Map<String, dynamic>? parent,
  String objectKey,
  String fieldKey,
  String fallback,
) {
  if (parent == null) {
    return fallback;
  }

  final object = parent[objectKey];

  if (object is Map) {
    return _string(
      object[fieldKey],
      fallback,
    );
  }

  return fallback;
}


int _nestedInt(
  Map<String, dynamic>? parent,
  String objectKey,
  String fieldKey,
) {
  if (parent == null) {
    return 0;
  }

  final object = parent[objectKey];

  if (object is Map) {
    return _int(object[fieldKey]);
  }

  return 0;
}
