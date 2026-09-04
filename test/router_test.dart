import 'dart:io';

import 'package:lite_server/lite_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('route table', () {
    test('flattens nested routes into absolute paths', () {
      final server = LiteServer(
        routes: [
          const HttpRoute.get(
            '/',
            handler: _noop,
            routes: [
              HttpRoute.get(
                'api',
                routes: [
                  HttpRoute.get('users', handler: _noop),
                ],
              ),
            ],
          ),
          const HttpRoute.get('/user/<id>/posts', handler: _noop),
        ],
      );

      expect(
        server.routeMap.keys,
        containsAll(['/', '/api/users', '/user/<id>/posts']),
      );
    });

    test('keeps routes that share a path but not a method', () {
      final server = LiteServer(
        routes: [
          const HttpRoute.get('/user/<id>', handler: _noop),
          const HttpRoute.post('/user/<id>', handler: _noop),
        ],
      );

      expect(server.routeMap['/user/<id>'], hasLength(2));
    });

    test('rejects two routes claiming the same path and method', () {
      expect(
        () => LiteServer(
          routes: [
            const HttpRoute.get('/user', handler: _noop),
            const HttpRoute.all('/user', handler: _noop),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a duplicated path parameter name', () {
      expect(
        () => LiteServer(
          routes: [const HttpRoute.get('/<id>/<id>', handler: _noop)],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a nested path that starts with a slash', () {
      expect(
        () => LiteServer(
          routes: [
            const HttpRoute.get(
              '/a',
              routes: [HttpRoute.get('/b', handler: _noop)],
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a top level path without a leading slash', () {
      expect(
        () => LiteServer(routes: [const HttpRoute.get('a', handler: _noop)]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('matching', () {
    late TestServer server;

    setUpAll(() async {
      server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              '/user/<id>',
              handler: (request, payload) => request.response
                  .json({'method': 'GET', ...payload.pathParameters}),
            ),
            HttpRoute.post(
              '/user/<id>',
              handler: (request, payload) => request.response
                  .json({'method': 'POST', ...payload.pathParameters}),
            ),
            HttpRoute.get(
              '/user/settings',
              handler: (request, payload) =>
                  request.response.json({'exact': true}),
            ),
            HttpRoute.get(
              '/report.json',
              handler: (request, payload) =>
                  request.response.json({'literal': true}),
            ),
            HttpRoute.get(
              '/files/<a>/<b>',
              handler: (request, payload) =>
                  request.response.json(payload.pathParameters),
            ),
            HttpRoute.put(
              '/things/<id>',
              handler: (request, payload) =>
                  request.response.json({'put': true}),
            ),
            HttpRoute(
              '/lowercase',
              methods: const {'get'},
              handler: (request, payload) =>
                  request.response.json({'ok': true}),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => server.close());

    test('dispatches on the method, not only the path', () async {
      expect((await server.get('/user/7')).json, {'method': 'GET', 'id': '7'});
      expect(
        (await server.send('POST', '/user/7')).json,
        {'method': 'POST', 'id': '7'},
      );
    });

    test('prefers a literal path over a matching parameter path', () async {
      expect((await server.get('/user/settings')).json, {'exact': true});
    });

    test('decodes percent encoded parameter values', () async {
      expect(
        (await server.get('/user/John%20Doe')).json,
        {'method': 'GET', 'id': 'John Doe'},
      );
    });

    test('captures every parameter of a multi parameter path', () async {
      expect((await server.get('/files/x/y')).json, {'a': 'x', 'b': 'y'});
    });

    test('does not let a parameter span path segments', () async {
      expect((await server.get('/user/a/b')).statusCode, HttpStatus.notFound);
    });

    test('treats dots in a literal path as literal characters', () async {
      expect((await server.get('/report.json')).json, {'literal': true});
      expect(
        (await server.get('/reportxjson')).statusCode,
        HttpStatus.notFound,
      );
    });

    test('ignores a trailing slash', () async {
      expect((await server.get('/user/settings/')).json, {'exact': true});
    });

    test('matches methods case insensitively', () async {
      expect((await server.get('/lowercase')).json, {'ok': true});
    });

    test('answers 405 with an Allow header when only the method is wrong',
        () async {
      final response = await server.send('DELETE', '/user/7');

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(
        response.header('allow'),
        allOf(contains('GET'), contains('POST')),
      );
    });

    test('answers 404 when nothing matches the path', () async {
      expect((await server.get('/nope')).statusCode, HttpStatus.notFound);
    });
  });
}

void _noop(HttpRequest request, HttpRoutePayload payload) {}
