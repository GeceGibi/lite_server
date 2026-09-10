import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class _RecordingController extends HttpController {
  _RecordingController(this.name, this.log, {this.revoke = false});

  final String name;
  final List<String> log;
  final bool revoke;

  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) async {
    log.add(name);

    if (revoke) {
      await request.response.status(HttpStatus.paymentRequired);
      return const HttpControllerBehavior.revoke();
    }

    return HttpControllerBehavior.next(extra: {name: true});
  }

  @override
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {
    log.add('$name:error');
  }
}

void main() {
  group('request size limit', () {
    test('rejects a declared Content-Length over the limit', () async {
      final server = await TestServer.start(
        LiteServer(
          maxRequestSize: 16,
          routes: [
            HttpRoute.post(
              path: '/echo',
              handler: (request, payload) async {
                final body = await request.readBodyAsString();
                await request.response.ok(body: body);
              },
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.send('POST', '/echo', body: 'x' * 5000);

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('rejects a chunked body over the limit', () async {
      final server = await TestServer.start(
        LiteServer(
          maxRequestSize: 16,
          routes: [
            HttpRoute.post(
              path: '/echo',
              handler: (request, payload) async {
                final body = await request.readBodyAsString();
                await request.response.ok(body: body);
              },
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.send(
        'POST',
        '/echo',
        body: 'x' * 5000,
        chunked: true,
      );

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('accepts a body inside the limit', () async {
      final server = await TestServer.start(
        LiteServer(
          maxRequestSize: 64,
          routes: [
            HttpRoute.post(
              path: '/echo',
              handler: (request, payload) async {
                final body = await request.readBodyAsString();
                await request.response.ok(body: body);
              },
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.send('POST', '/echo', body: 'hello');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'hello');
    });
  });

  group('controllers', () {
    test('run global before route controllers and collect extras', () async {
      final log = <String>[];

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/x',
              controllers: [_RecordingController('route', log)],
              handler: (request, payload) => request.response.json(
                payload.extras.keys.toList(),
              ),
            ),
          ],
        ),
        controllers: [_RecordingController('global', log)],
      );
      addTearDown(server.close);

      final response = await server.get('/x');

      expect(log, ['global', 'route']);
      expect(response.json, ['global', 'route']);
    });

    test('a revoking controller stops the chain', () async {
      final log = <String>[];

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/x',
              handler: (request, payload) =>
                  request.response.ok(body: 'reached'),
            ),
          ],
        ),
        controllers: [_RecordingController('gate', log, revoke: true)],
      );
      addTearDown(server.close);

      final response = await server.get('/x');

      expect(response.statusCode, HttpStatus.paymentRequired);
      expect(response.body, isNot(contains('reached')));
    });

    test('controller error listeners see a handler failure', () async {
      final log = <String>[];

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/boom',
              handler: (request, payload) => throw StateError('x'),
            ),
          ],
        ),
        controllers: [_RecordingController('global', log)],
      );
      addTearDown(server.close);

      final response = await server.get('/boom');

      expect(response.statusCode, HttpStatus.internalServerError);
      expect(log, contains('global:error'));
    });
  });

  group('error handling', () {
    test('a throwing handler yields 500', () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/boom',
              handler: (request, payload) => throw StateError('x'),
            ),
          ],
        ),
      );
      addTearDown(server.close);

      expect(
        (await server.get('/boom')).statusCode,
        HttpStatus.internalServerError,
      );
    });

    test('a handler that throws after responding does not break the server',
        () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/late',
              handler: (request, payload) async {
                await request.response.ok(body: 'sent');
                throw StateError('after close');
              },
            ),
            HttpRoute.get(
              path: '/ping',
              handler: (request, payload) => request.response.ok(body: 'pong'),
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.get('/late');
      expect(response.body, 'sent');

      /// The server must still be serving after the failed error response.
      expect((await server.get('/ping')).body, 'pong');
    });

    test('onError replaces the default 500 response', () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/boom',
              handler: (request, payload) => throw StateError('x'),
            ),
          ],
          onError: (request, error, stackTrace) {
            request.response
                .status(HttpStatus.badGateway, body: 'handled')
                .ignore();
          },
        ),
      );
      addTearDown(server.close);

      final response = await server.get('/boom');

      expect(response.statusCode, HttpStatus.badGateway);
      expect(response.body, 'handled');
    });

    test('onError passed to listen is used as a fallback', () async {
      final seen = <Object?>[];

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/boom',
              handler: (request, payload) => throw StateError('x'),
            ),
          ],
        ),
        onError: (request, error, stackTrace) {
          seen.add(error);
          request.response.status(HttpStatus.serviceUnavailable).ignore();
        },
      );
      addTearDown(server.close);

      final response = await server.get('/boom');

      expect(response.statusCode, HttpStatus.serviceUnavailable);
      expect(seen, hasLength(1));
    });

    test('onRouteNotFound replaces the default 404 response', () async {
      final server = await TestServer.start(
        LiteServer(
          onRouteNotFound: (request) =>
              request.response.status(HttpStatus.gone, body: 'custom'),
        ),
      );
      addTearDown(server.close);

      final response = await server.get('/missing');

      expect(response.statusCode, HttpStatus.gone);
      expect(response.body, 'custom');
    });
  });

  group('timeout', () {
    test('answers 408 when a handler never responds', () async {
      final server = await TestServer.start(
        LiteServer(
          requestTimeout: const Duration(milliseconds: 150),
          routes: [
            HttpRoute.get(
              path: '/slow',
              handler: (request, payload) => Completer<void>().future,
            ),
          ],
        ),
      );
      addTearDown(server.close);

      expect(
        (await server.get('/slow')).statusCode,
        HttpStatus.requestTimeout,
      );
    });

    test('does not fire for a handler that responds in time', () async {
      final server = await TestServer.start(
        LiteServer(
          requestTimeout: const Duration(milliseconds: 500),
          routes: [
            HttpRoute.get(
              path: '/quick',
              handler: (request, payload) => request.response.ok(body: 'fast'),
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.get('/quick');

      expect(response.statusCode, HttpStatus.ok);

      /// Outlive the timeout to prove the timer was cancelled and cannot
      /// touch the already closed response.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect((await server.get('/quick')).body, 'fast');
    });
  });

  test('listen returns a subscription that can be cancelled', () async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => httpServer.close(force: true));

    final subscription = LiteServer(
      routes: [
        HttpRoute.get(
          path: '/x',
          handler: (request, payload) => request.response.ok(),
        ),
      ],
    ).listen(httpServer, logStartup: false);

    expect(subscription, isA<StreamSubscription<HttpRequest>>());
    await subscription.cancel();
  });
}
