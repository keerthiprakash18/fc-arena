/// Group-stage models.
///
/// A group table is built server-side from verified matches only, so an empty
/// table means "nothing has been played yet", not "no data available".
class GroupTable {
  final int groupId;
  final String name;
  final int groupNumber;
  final List<GroupRow> rows;

  GroupTable({
    required this.groupId,
    required this.name,
    required this.groupNumber,
    required this.rows,
  });

  factory GroupTable.fromJson(Map<String, dynamic> json) => GroupTable(
        groupId: json['group_id'] ?? 0,
        name: json['name'] ?? 'Group',
        groupNumber: json['group_number'] ?? 0,
        rows: ((json['standings'] as List?) ?? const [])
            .map((r) => GroupRow.fromJson((r as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// True when no fixture in this group has been verified yet.
  bool get isUnplayed => rows.every((r) => r.played == 0);
}

class GroupRow {
  final int rank;
  final int participantId;
  final String name;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  GroupRow({
    required this.rank,
    required this.participantId,
    required this.name,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory GroupRow.fromJson(Map<String, dynamic> json) => GroupRow(
        rank: json['rank'] ?? 0,
        participantId: json['participant_id'] ?? 0,
        name: json['name'] ?? '',
        played: json['played'] ?? 0,
        wins: json['wins'] ?? 0,
        draws: json['draws'] ?? 0,
        losses: json['losses'] ?? 0,
        goalsFor: json['goals_for'] ?? 0,
        goalsAgainst: json['goals_against'] ?? 0,
        goalDifference: json['goal_difference'] ?? 0,
        points: json['points'] ?? 0,
      );

  String get goalDifferenceLabel =>
      goalDifference > 0 ? '+$goalDifference' : '$goalDifference';
}
