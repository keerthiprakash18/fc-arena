import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/models/search.dart';

/// Parsing tests for the search payload.
///
/// The screen relies on every bucket always being present, so the important
/// cases are the missing/empty ones rather than the happy path.
void main() {
  test('parses every bucket from a full payload', () {
    final results = SearchResults.fromJson({
      'query': 'nova',
      'teams': [
        {'id': 1, 'name': 'Nova Stars', 'short_name': 'Nova', 'logo': null, 'game': 'FC Mobile'},
      ],
      'tournaments': [
        {'id': 2, 'name': 'Winter Cup', 'tournament_code': 'WC1', 'status': 'DRAFT', 'format': 'KNOCKOUT'},
      ],
      'players': [
        {'id': 3, 'username': 'bob', 'display_name': 'Bob Smith'},
      ],
      'matches': [
        {
          'id': 4,
          'home_display': 'Nova Stars',
          'away_display': 'Thunder FC',
          'home_score': 3,
          'away_score': 1,
          'status': 'VERIFIED',
          'scheduled_at': null,
          'round_name': 'Final',
        },
      ],
    });

    expect(results.query, 'nova');
    expect(results.teams.single.name, 'Nova Stars');
    expect(results.tournaments.single.code, 'WC1');
    expect(results.players.single.displayName, 'Bob Smith');
    expect(results.matches.single.roundName, 'Final');
    expect(results.total, 4);
    expect(results.isEmpty, isFalse);
  });

  test('missing buckets become empty lists rather than crashing', () {
    final results = SearchResults.fromJson({'query': 'x'});

    expect(results.teams, isEmpty);
    expect(results.tournaments, isEmpty);
    expect(results.players, isEmpty);
    expect(results.matches, isEmpty);
    expect(results.isEmpty, isTrue);
    expect(results.total, 0);
  });

  test('null buckets are tolerated', () {
    final results = SearchResults.fromJson({
      'query': 'x',
      'teams': null,
      'matches': null,
    });

    expect(results.isEmpty, isTrue);
  });

  test('an empty payload reports no results', () {
    expect(SearchResults.empty().isEmpty, isTrue);
    expect(SearchResults.empty().total, 0);
  });

  group('SearchMatch', () {
    test('reports a score once both sides are present', () {
      final played = SearchMatch.fromJson({
        'id': 1,
        'home_display': 'A',
        'away_display': 'B',
        'home_score': 2,
        'away_score': 0,
      });

      expect(played.hasScore, isTrue);
      expect(played.scoreLabel, '2 - 0');
    });

    test('shows "vs" when the fixture has not been played', () {
      final upcoming = SearchMatch.fromJson({
        'id': 1,
        'home_display': 'A',
        'away_display': 'B',
      });

      expect(upcoming.hasScore, isFalse);
      expect(upcoming.scoreLabel, 'vs');
    });

    test('a zero-nil result is not mistaken for "no score"', () {
      final goalless = SearchMatch.fromJson({
        'id': 1,
        'home_display': 'A',
        'away_display': 'B',
        'home_score': 0,
        'away_score': 0,
      });

      expect(goalless.hasScore, isTrue);
      expect(goalless.scoreLabel, '0 - 0');
    });

    test('falls back to TBD when a side is unnamed', () {
      final match = SearchMatch.fromJson({'id': 1});
      expect(match.homeDisplay, 'TBD');
      expect(match.awayDisplay, 'TBD');
    });
  });

  group('SearchTournament', () {
    test('humanises the status enum', () {
      final t = SearchTournament.fromJson({
        'id': 1,
        'name': 'Cup',
        'status': 'REGISTRATION_OPEN',
        'format': 'KNOCKOUT',
      });
      expect(t.statusLabel, 'Registration open');
    });

    test('reads the code from tournament_code', () {
      final t = SearchTournament.fromJson({
        'id': 1,
        'name': 'Cup',
        'tournament_code': 'ABC12',
      });
      expect(t.code, 'ABC12');
    });
  });

  group('SearchPlayer', () {
    test('falls back to the username when there is no display name', () {
      final p = SearchPlayer.fromJson({'id': 1, 'username': 'bob'});
      expect(p.displayName, 'bob');
    });
  });
}
