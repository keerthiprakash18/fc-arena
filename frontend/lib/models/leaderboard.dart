class LeaderboardEntry {
  final int id;
  final String category;
  final String username;
  final double? value;
  final int? rank;
  final String? calculatedAt;

  LeaderboardEntry({
    required this.id,
    required this.category,
    required this.username,
    this.value,
    this.rank,
    this.calculatedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    id: json['id'] ?? 0,
    category: json['category'] ?? '',
    username: json['username'] ?? json['user__username'] ?? '',
    value: _parseDouble(json['value']),
    rank: json['rank'],
    calculatedAt: json['calculated_at'],
  );

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String get categoryLabel {
    switch (category) {
      case 'RATING': return 'Rating';
      case 'WINS': return 'Wins';
      case 'GOALS': return 'Goals';
      case 'WIN_RATE': return 'Win Rate';
      case 'GOAL_DIFF': return 'Goal Diff';
      case 'MATCHES': return 'Matches';
      case 'CLEAN_SHEETS': return 'Clean Sheets';
      default: return category;
    }
  }
}

class PlayerStanding {
  final int? userId;
  final String username;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final int goalsScored;
  final int goalsConceded;
  final int goalDifference;
  final int points;

  PlayerStanding({
    this.userId,
    required this.username,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsScored,
    required this.goalsConceded,
    required this.goalDifference,
    required this.points,
  });

  factory PlayerStanding.fromJson(Map<String, dynamic> json) => PlayerStanding(
    userId: json['user'],
    username: json['username'] ?? '',
    matchesPlayed: json['matches_played'] ?? 0,
    wins: json['wins'] ?? 0,
    draws: json['draws'] ?? 0,
    losses: json['losses'] ?? 0,
    goalsScored: json['goals_scored'] ?? json['goals_for'] ?? 0,
    goalsConceded: json['goals_conceded'] ?? json['goals_against'] ?? 0,
    goalDifference: json['goal_difference'] ?? 0,
    points: json['points'] ?? 0,
  );
}