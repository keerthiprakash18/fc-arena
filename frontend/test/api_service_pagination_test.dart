import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/config/api.dart';
import 'package:fc_arena/services/api_service.dart';

/// Proves the list methods return the *whole* collection, not page one.
///
/// The API caps every page at 20 rows and exposes no page-size parameter, so a
/// list method built on `getList` silently showed the first 20 of N — 20 of 38
/// fixtures, half a knockout bracket, the first 20 of a season's awards. These
/// tests use a real two-page server so a regression to `getList` fails loudly
/// rather than quietly dropping rows.
///
/// Plain `test()` rather than `testWidgets()`: the widget binding stubs HTTP to
/// status 400, which would make a real socket impossible.
void main() {
  late HttpServer server;
  late int port;

  /// Serves [total] items across pages of 20, following the DRF envelope.
  Future<void> startPagedServer(String path, int total) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      final page = int.tryParse(request.uri.queryParameters['page'] ?? '1') ?? 1;
      final start = (page - 1) * 20;
      final end = (start + 20).clamp(0, total);
      final hasNext = end < total;

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'count': total,
          'next': hasNext ? 'http://127.0.0.1:$port$path?page=${page + 1}' : null,
          'previous': page > 1 ? 'http://127.0.0.1:$port$path?page=${page - 1}' : null,
          'results': [
            for (var i = start; i < end; i++) {'id': i + 1, 'status': 'SCHEDULED'},
          ],
        }));
      await request.response.close();
    });
  }

  tearDown(() async => server.close(force: true));

  test('getLeagueMatches returns every fixture, not the first 20', () async {
    await startPagedServer('/leagues/1/matches/', 38);

    await setApiBaseUrl('http://127.0.0.1:$port');
    final matches = await ApiService(ApiClient()).getLeagueMatches(1);

    expect(matches.length, 38,
        reason: 'a season longer than one page must not be truncated');
    expect(matches.first.id, 1);
    expect(matches.last.id, 38);
  });

  test('getTournaments returns every tournament', () async {
    await startPagedServer('/leagues/1/tournaments/', 25);

    await setApiBaseUrl('http://127.0.0.1:$port');
    final tournaments = await ApiService(ApiClient()).getTournaments(1);

    expect(tournaments.length, 25);
  });

  test('getAwards returns every award', () async {
    await startPagedServer('/leagues/1/awards/', 27);

    await setApiBaseUrl('http://127.0.0.1:$port');
    final awards = await ApiService(ApiClient()).getAwards(1);

    expect(awards.length, 27);
  });

  test('a single-page collection is unaffected', () async {
    await startPagedServer('/leagues/1/matches/', 4);

    await setApiBaseUrl('http://127.0.0.1:$port');
    final matches = await ApiService(ApiClient()).getLeagueMatches(1);

    expect(matches.length, 4);
  });
}
