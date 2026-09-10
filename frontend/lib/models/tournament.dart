class Tournament {
  final int id;
  final int leagueId;
  final String leagueName;
  final int? seasonId;
  final String name;
  final String description;
  final String code;
  final String format;
  final String status;
  final int maxParticipants;
  final double entryFee;
  final double prizePool;
  final String? registrationDeadline;
  final String? startDate;
  final String? endDate;
  final String createdBy;
  final int participantCount;
  final String createdAt;

  Tournament({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    this.seasonId,
    required this.name,
    required this.description,
    required this.code,
    required this.format,
    required this.status,
    required this.maxParticipants,
    required this.entryFee,
    required this.prizePool,
    this.registrationDeadline,
    this.startDate,
    this.endDate,
    required this.createdBy,
    required this.participantCount,
    required this.createdAt,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    leagueName: json['league_name'] ?? '',
    seasonId: json['season'],
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    code: json['tournament_code'] ?? '',
    format: json['format'] ?? 'KNOCKOUT',
    status: json['status'] ?? 'DRAFT',
    maxParticipants: json['max_participants'] ?? 16,
    entryFee: (json['entry_fee'] ?? 0).toDouble(),
    prizePool: (json['prize_pool'] ?? 0).toDouble(),
    registrationDeadline: json['registration_deadline'],
    startDate: json['start_date'],
    endDate: json['end_date'],
    createdBy: json['created_by_name'] ?? '',
    participantCount: json['participant_count'] ?? 0,
    createdAt: json['created_at'] ?? '',
  );

  bool get canRegister => status == 'REGISTRATION_OPEN';

  String get statusLabel {
    switch (status) {
      case 'REGISTRATION_OPEN': return 'Registration Open';
      case 'IN_PROGRESS': return 'In Progress';
      case 'COMPLETED': return 'Completed';
      default: return status.replaceAll('_', ' ');
    }
  }

  String get formatLabel {
    switch (format) {
      case 'KNOCKOUT': return 'Knockout';
      case 'LEAGUE': return 'League';
      case 'GROUP_KNOCKOUT': return 'Group + Knockout';
      default: return format;
    }
  }
}

class TournamentParticipant {
  final int id;
  final String username;
  final String status;
  final int? seedNumber;

  TournamentParticipant({required this.id, required this.username, required this.status, this.seedNumber});

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) => TournamentParticipant(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    status: json['status'] ?? 'REGISTERED',
    seedNumber: json['seed_number'],
  );
}

class TournamentRound {
  final int id;
  final String name;
  final int roundNumber;
  final String roundType;
  final bool isCurrent;

  TournamentRound({required this.id, required this.name, required this.roundNumber,
    required this.roundType, required this.isCurrent});

  factory TournamentRound.fromJson(Map<String, dynamic> json) => TournamentRound(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    roundNumber: json['round_number'] ?? 0,
    roundType: json['round_type'] ?? 'KNOCKOUT',
    isCurrent: json['is_current'] ?? false,
  );
}