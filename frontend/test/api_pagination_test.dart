import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/config/api.dart';

/// Exercises [ApiClient.getListAll] against a real local HTTP server.
///
/// The API paginates at 20 rows per page, so anything that needs the full set
/// (a knockout bracket, a fixture list, a season table) must follow `next`.
/// These tests pin that behaviour down with an actual two-page response rather
/// than trusting the loop by inspection.
///
/// Deliberately plain `test()` rather than `testWidgets()`: the widget binding
/// stubs every HTTP request to status 400, which would make a real socket
/// impossible. No binding is initialised here, so `dart:io` works normally.
/// `setApiBaseUrl` assigns its global before it touches SharedPreferences, and
/// the prefs call is swallowed internally, so no mock store is needed.
void main() {
  late HttpServer server;
  late int port;

  /// Serves `payloadFor(hitIndex)` for each successive request.
  ///
  /// [status] applies to every response, so error handling can be exercised too.
  Future<void> startServer(
    Object Function(int hit) payloadFor, {
    int status = 200,
  }) async {
    var hits = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      final body = payloadFor(hits);
      hits++;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(body is String ? body : jsonEncode(body));
      await request.response.close();
    });
  }

  tearDown(() async => server.close(force: true));

  test('walks an absolute next link and collects every page', () async {
    var hits = 0;
    await startServer((hit) {
      hits++;
      if (hit == 0) {
        return {
          'count': 3,
          'next': 'http://127.0.0.1:$port/items/?page=2',
          'previous': null,
          'results': [
            {'id': 1},
            {'id': 2},
          ],
        };
      }
      return {
        'count': 3,
        'next': null,
        'previous': 'http://127.0.0.1:$port/items/?page=1',
        'results': [
          {'id': 3},
        ],
      };
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    final data = await ApiClient().getListAll('/items/');

    final ids = (data['results'] as List).map((e) => (e as Map)['id']).toList();
    expect(ids, [1, 2, 3]);
    expect(hits, 2, reason: 'exactly two pages exist');
  });

  test('stops when next is null instead of requesting again', () async {
    var hits = 0;
    await startServer((hit) {
      hits++;
      return {
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      };
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    final data = await ApiClient().getListAll('/items/');

    expect((data['results'] as List).length, 2);
    expect(hits, 1, reason: 'no pointless second request');
  });

  test('passes an unpaginated payload straight through', () async {
    await startServer((_) => [
          {'id': 1},
          {'id': 2},
        ]);

    await setApiBaseUrl('http://127.0.0.1:$port');
    final data = await ApiClient().getListAll('/items/');

    expect((data['results'] as List).length, 2);
  });

  test('surfaces API errors instead of returning an empty list', () async {
    await startServer((_) => {'detail': 'Not found.'}, status: 404);

    await setApiBaseUrl('http://127.0.0.1:$port');

    await expectLater(
      ApiClient().getListAll('/items/'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a malformed next chain cannot loop forever', () async {
    var hits = 0;
    await startServer((hit) {
      hits++;
      return {
        'count': 1,
        'next': 'http://127.0.0.1:$port/items/?page=2',
        'previous': null,
        'results': [
          {'id': 1},
        ],
      };
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    await ApiClient().getListAll('/items/');

    expect(hits, lessThanOrEqualTo(100), reason: 'guard caps the walk');
  });
}
