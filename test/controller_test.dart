import 'dart:io';

import 'package:lite_server/lite_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  Future<TestServer> serve(CorsOriginController cors) {
    return TestServer.start(
      LiteServer(
        routes: [
          HttpRoute.all(
            path: '/x',
            handler: (request, payload) => request.response.ok(body: 'ok'),
          ),
        ],
      ),
      controllers: [cors],
    );
  }

  group('CorsOriginController', () {
    test('echoes a single allowed origin instead of the whole list', () async {
      final server = await serve(
        CorsOriginController(
          allowedOrigins: {'https://a.test', 'https://b.test'},
        ),
      );
      addTearDown(server.close);

      final response = await server.get(
        '/x',
        headers: {'origin': 'https://b.test'},
      );

      expect(
        response.headers['access-control-allow-origin'],
        ['https://b.test'],
      );
      expect(response.header('vary'), contains('Origin'));
    });

    test('omits the origin header for an origin outside the list', () async {
      final server = await serve(
        CorsOriginController(allowedOrigins: {'https://a.test'}),
      );
      addTearDown(server.close);

      final response = await server.get(
        '/x',
        headers: {'origin': 'https://evil.test'},
      );

      expect(response.header('access-control-allow-origin'), isNull);
      expect(response.statusCode, HttpStatus.ok);
    });

    test('never pairs a wildcard origin with credentials', () async {
      final server = await serve(CorsOriginController());
      addTearDown(server.close);

      final response = await server.get(
        '/x',
        headers: {'origin': 'https://any.test'},
      );

      expect(
        response.header('access-control-allow-origin'),
        'https://any.test',
      );
      expect(response.header('access-control-allow-credentials'), 'true');
    });

    test('uses a wildcard origin when credentials are off', () async {
      final server = await serve(
        CorsOriginController(allowCredentials: false),
      );
      addTearDown(server.close);

      final response = await server.get(
        '/x',
        headers: {'origin': 'https://any.test'},
      );

      expect(response.header('access-control-allow-origin'), '*');
      expect(response.header('access-control-allow-credentials'), isNull);
    });

    test('answers a preflight with 204 and the negotiated headers', () async {
      final server = await serve(
        CorsOriginController(
          allowedOrigins: {'https://a.test'},
          allowedMethods: {'GET', 'POST', 'OPTIONS'},
          maxAge: const Duration(minutes: 10),
        ),
      );
      addTearDown(server.close);

      final response = await server.send(
        'OPTIONS',
        '/x',
        headers: {
          'origin': 'https://a.test',
          'access-control-request-method': 'POST',
        },
      );

      expect(response.statusCode, HttpStatus.noContent);
      expect(response.header('access-control-allow-methods'), contains('POST'));
      expect(response.header('access-control-max-age'), '600');
    });

    test('omits an empty expose-headers header', () async {
      final server = await serve(CorsOriginController());
      addTearDown(server.close);

      final response = await server.get(
        '/x',
        headers: {'origin': 'https://any.test'},
      );

      expect(response.header('access-control-expose-headers'), isNull);
    });

    test('refuses a method outside allowedMethods with an Allow header',
        () async {
      final server = await serve(
        CorsOriginController(allowedMethods: {'GET'}),
      );
      addTearDown(server.close);

      final response = await server.send('DELETE', '/x');

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(response.header('allow'), contains('GET'));
    });
  });

  group('LoggerController', () {
    test('does not create a log directory when logging is disabled', () async {
      final root = Directory.systemTemp.createTempSync('lite_server_logs');
      addTearDown(() => root.deleteSync(recursive: true));

      final logDirectory = Directory('${root.path}/logs');

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/x',
              handler: (request, payload) => request.response.ok(),
            ),
          ],
        ),
        controllers: [
          LoggerController(path: logDirectory.path, printLogs: false),
        ],
      );
      addTearDown(server.close);

      await server.get('/x');

      expect(logDirectory.existsSync(), isFalse);
    });

    test('writes one request line per request', () async {
      final root = Directory.systemTemp.createTempSync('lite_server_logs');
      addTearDown(() => root.deleteSync(recursive: true));

      final controller = LoggerController(
        level: LogLevel.requests,
        path: '${root.path}/logs',
        printLogs: false,
      );
      addTearDown(controller.logger.close);

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              path: '/x',
              handler: (request, payload) => request.response.ok(),
            ),
          ],
        ),
        controllers: [controller],
      );
      addTearDown(server.close);

      await server.get('/x');
      await server.get('/x');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final lines = controller.logger.logFileRequests
          .readAsLinesSync()
          .where((line) => line.isNotEmpty);

      expect(lines, hasLength(2));
      expect(lines.first, contains('GET'));
    });

    test('two loggers keep separate files', () async {
      final root = Directory.systemTemp.createTempSync('lite_server_logs');
      addTearDown(() => root.deleteSync(recursive: true));

      final first = LiteServerLogger(path: '${root.path}/a');
      final second = LiteServerLogger(path: '${root.path}/b');
      addTearDown(first.close);
      addTearDown(second.close);

      first.appendRequestLine('from-a');
      second.appendRequestLine('from-b');

      expect(first.logFileRequests.readAsStringSync().trim(), 'from-a');
      expect(second.logFileRequests.readAsStringSync().trim(), 'from-b');
    });

    test('collapses a multi line entry onto one row', () async {
      final root = Directory.systemTemp.createTempSync('lite_server_logs');
      addTearDown(() => root.deleteSync(recursive: true));

      final logger = LiteServerLogger(path: '${root.path}/logs');
      addTearDown(logger.close);

      logger.appendErrorLine('line one\nline two\nline three');

      final lines = logger.logFileErrors
          .readAsLinesSync()
          .where((line) => line.isNotEmpty);

      expect(lines, hasLength(1));
      expect(lines.single, 'line one, line two, line three');
    });
  });
}
