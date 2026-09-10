class Season {
  final int id;
  final int leagueId;
  final String leagueName;
  final String name;
  final String slug;
  final String description;
  final String status;
  final String? startDate;
  final String? endDate;
  final bool isCurrent;
  final int memberCount;
  final String createdAt;

  Season({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    required this.name,
    required this.slug,
    required this.description,
    required this.status,
    this.startDate,
    this.endDate,
    required this.isCurrent,
    required this.memberCount,
    required this.createdAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    leagueName: json['league_name'] ?? '',
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    description: json['description'] ?? '',
    status: json['status'] ?? 'DRAFT',
    startDate: json['start_date'],
    endDate: json['end_date'],
    isCurrent: json['is_current'] ?? false,
    memberCount: json['member_count'] ?? 0,
    createdAt: json['created_at'] ?? '',
  );

  String get statusLabel {
    switch (status) {
      case 'ACTIVE': return 'Active';
      case 'COMPLETED': return 'Completed';
      case 'ARCHIVED': return 'Archived';
      default: return 'Draft';
    }
  }
}

class SeasonMember {
  final int id;
  final String username;
  final bool isActive;

  SeasonMember({required this.id, required this.username, required this.isActive});

  factory SeasonMember.fromJson(Map<String, dynamic> json) => SeasonMember(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    isActive: json['is_active'] ?? true,
  );
}