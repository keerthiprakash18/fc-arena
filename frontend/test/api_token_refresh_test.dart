import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fc_arena/config/api.dart';

/// Pins down the 401 → refresh → retry path against a real local HTTP server.
///
/// This used to be broken: the refresh happened inside the response decoder,
/// which then decoded the *same* already-consumed 401 response, so a refresh
/// that succeeded still surfaced to the caller as a failure. Anything with an
/// expired access token looked like a spurious logout.
///
/// Deliberately plain `test()` rather than `testWidgets()`: the widget binding
/// stubs every HTTP request to status 400, which would make a real socket
/// impossible. [ApiClient.saveTokens] assigns its in-memory fields before it
/// touches SharedPreferences and swallows the prefs failure, so seeding a token
/// needs no mock store.
void main() {
  late HttpServer server;
  late int port;
  late List<String> requestLog;

  Future<void> startServer(Future<void> Function(HttpRequest) handle) async {
    requestLog = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
    server.listen((request) async {
      requestLog.add('${request.method} ${request.uri.path}');
      await handle(request);
    });
  }

  Future<void> respond(
    HttpRequest request,
    int status,
    Object body,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  tearDown(() async => server.close(force: true));

  test('refreshes an expired token and retries the original request', () async {
    var itemHits = 0;
    await startServer((request) async {
      if (request.uri.path == '/auth/refresh/') {
        return respond(request, 200, {'access': 'fresh-access'});
      }
      itemHits++;
      if (itemHits == 1) {
        return respond(request, 401, {'detail': 'Token is invalid or expired'});
      }
      return respond(request, 200, {
        'ok': true,
        'authorization': request.headers.value('authorization'),
      });
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    final client = ApiClient();
    await client.saveTokens('stale-access', 'valid-refresh');

    final data = await client.get('/items/');

    expect(data['ok'], true,
        reason: 'the retry result must reach the caller, not the 401');
    expect(itemHits, 2, reason: 'the original request is re-issued exactly once');
    expect(data['authorization'], 'Bearer fresh-access',
        reason: 'the retry must carry the refreshed access token');
    expect(requestLog, contains('POST /auth/refresh/'));
  });

  test('does not refresh when there is no refresh token', () async {
    await startServer((request) => respond(request, 401, {'detail': 'Unauthorized'}));

    await setApiBaseUrl('http://127.0.0.1:$port');
    final client = ApiClient(); // no tokens seeded

    await expectLater(client.get('/items/'), throwsA(isA<ApiException>()));
    expect(requestLog.where((r) => r.contains('/auth/refresh/')), isEmpty,
        reason: 'nothing to refresh with, so do not call the endpoint');
  });

  test('a failed refresh surfaces the original 401 rather than looping',
      () async {
    var itemHits = 0;
    await startServer((request) async {
      if (request.uri.path == '/auth/refresh/') {
        return respond(request, 401, {'detail': 'Refresh token is invalid'});
      }
      itemHits++;
      return respond(request, 401, {'detail': 'Token is invalid or expired'});
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    final client = ApiClient();
    await client.saveTokens('stale-access', 'stale-refresh');

    await expectLater(client.get('/items/'), throwsA(isA<ApiException>()));
    expect(itemHits, 1, reason: 'a dead refresh token must not cause a retry loop');
  });

  test('a 401 on a paginated walk is retried instead of truncating the list',
      () async {
    var page1Hits = 0;
    await startServer((request) async {
      if (request.uri.path == '/auth/refresh/') {
        return respond(request, 200, {'access': 'fresh-access'});
      }
      if (request.uri.queryParameters['page'] == '2') {
        return respond(request, 200, {
          'count': 3,
          'next': null,
          'previous': null,
          'results': [
            {'id': 3},
          ],
        });
      }
      page1Hits++;
      if (page1Hits == 1) {
        return respond(request, 401, {'detail': 'Token is invalid or expired'});
      }
      return respond(request, 200, {
        'count': 3,
        'next': 'http://127.0.0.1:$port/items/?page=2',
        'previous': null,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      });
    });

    await setApiBaseUrl('http://127.0.0.1:$port');
    final client = ApiClient();
    await client.saveTokens('stale-access', 'valid-refresh');

    final data = await client.getListAll('/items/');
    final ids = (data['results'] as List).map((e) => (e as Map)['id']).toList();

    expect(ids, [1, 2, 3],
        reason: 'the walk must survive a token expiry mid-collection');
  });

  test('a successful response is decoded without touching the refresh endpoint',
      () async {
    await startServer((request) => respond(request, 200, {'ok': true}));

    await setApiBaseUrl('http://127.0.0.1:$port');
    final client = ApiClient();
    await client.saveTokens('good-access', 'valid-refresh');

    final data = await client.get('/items/');

    expect(data['ok'], true);
    expect(requestLog, ['GET /items/'],
        reason: 'no refresh round-trip when the token is fine');
  });
}
