/// Results of a league-wide search.
///
/// Every bucket is always present, so the UI can distinguish "nothing matched"
/// from "this category was not searched".
class SearchResults {
  final String query;
  final List<SearchTeam> teams;
  final List<SearchTournament> tournaments;
  final List<SearchPlayer> players;
  final List<SearchMatch> matches;

  SearchResults({
    required this.query,
    required this.teams,
    required this.tournaments,
    required this.players,
    required this.matches,
  });

  factory SearchResults.empty() => SearchResults(
        query: '',
        teams: const [],
        tournaments: const [],
        players: const [],
        matches: const [],
      );

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) =>
        ((json[key] as List?) ?? const [])
            .map((e) => build((e as Map).cast<String, dynamic>()))
            .toList();

    return SearchResults(
      query: json['query'] ?? '',
      teams: parse('teams', SearchTeam.fromJson),
      tournaments: parse('tournaments', SearchTournament.fromJson),
      players: parse('players', SearchPlayer.fromJson),
      matches: parse('matches', SearchMatch.fromJson),
    );
  }

  int get total =>
      teams.length + tournaments.length + players.length + matches.length;

  bool get isEmpty => total == 0;
}

class SearchTeam {
  final int id;
  final String name;
  final String shortName;
  final String? logo;
  final String game;

  SearchTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.logo,
    required this.game,
  });

  factory SearchTeam.fromJson(Map<String, dynamic> json) => SearchTeam(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        shortName: json['short_name'] ?? '',
        logo: json['logo'],
        game: json['game'] ?? '',
      );
}

class SearchTournament {
  final int id;
  final String name;
  final String code;
  final String status;
  final String format;

  SearchTournament({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.format,
  });

  factory SearchTournament.fromJson(Map<String, dynamic> json) => SearchTournament(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        code: json['tournament_code'] ?? '',
        status: json['status'] ?? '',
        format: json['format'] ?? '',
      );

  String get statusLabel =>
      status.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(
            RegExp(r'^.'), (m) => m.group(0)!.toUpperCase(),
          );
}

class SearchPlayer {
  final int id;
  final String username;
  final String displayName;

  SearchPlayer({
    required this.id,
    required this.username,
    required this.displayName,
  });

  factory SearchPlayer.fromJson(Map<String, dynamic> json) => SearchPlayer(
        id: json['id'] ?? 0,
        username: json['username'] ?? '',
        displayName: json['display_name'] ?? json['username'] ?? '',
      );
}

class SearchMatch {
  final int id;
  final String homeDisplay;
  final String awayDisplay;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final String? scheduledAt;
  final String? roundName;

  SearchMatch({
    required this.id,
    required this.homeDisplay,
    required this.awayDisplay,
    this.homeScore,
    this.awayScore,
    required this.status,
    this.scheduledAt,
    this.roundName,
  });

  factory SearchMatch.fromJson(Map<String, dynamic> json) => SearchMatch(
        id: json['id'] ?? 0,
        homeDisplay: json['home_display'] ?? 'TBD',
        awayDisplay: json['away_display'] ?? 'TBD',
        homeScore: json['home_score'],
        awayScore: json['away_score'],
        status: json['status'] ?? '',
        scheduledAt: json['scheduled_at'],
        roundName: json['round_name'],
      );

  bool get hasScore => homeScore != null && awayScore != null;

  String get scoreLabel => hasScore ? '$homeScore - $awayScore' : 'vs';
}
