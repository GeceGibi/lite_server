import 'dart:io';

import 'package:lite_server/lite_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late Directory sandbox;
  late Directory public;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('lite_server_static');
    public = Directory('${sandbox.path}/public')..createSync();

    File('${public.path}/hello.txt').writeAsStringSync('hello');
    File('${public.path}/index.html').writeAsStringSync('<h1>home</h1>');
    File('${public.path}/logo.png').writeAsStringSync('not-really-a-png');
    File('${public.path}/.env').writeAsStringSync('SECRET=1');
    Directory('${public.path}/nested').createSync();
    File('${public.path}/nested/deep.txt').writeAsStringSync('deep');

    /// Lives next to, but outside of, the served directory.
    File('${sandbox.path}/secret.txt').writeAsStringSync('do-not-serve');
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  Future<TestServer> serve({
    String? defaultDocument,
    bool listDirectory = false,
    Set<String> allowedExtensions = const {},
    String mount = '/assets',
    List<HttpRoute> extraRoutes = const [],
  }) {
    return TestServer.start(
      LiteServer(
        routes: [
          ...extraRoutes,
          HttpStaticRoute(
            mount,
            directoryPath: public.path,
            defaultDocument: defaultDocument,
            listDirectory: listDirectory,
            allowedExtensions: allowedExtensions,
          ),
        ],
      ),
    );
  }

  group('serving', () {
    test('serves a file with its content type and length', () async {
      final server = await serve();
      addTearDown(server.close);

      final response = await server.get('/assets/hello.txt');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'hello');
      expect(response.header('content-type'), contains('text/plain'));
      expect(response.header('content-length'), '5');
      expect(response.header('last-modified'), isNotNull);
    });

    test('serves a file from a subdirectory', () async {
      final server = await serve();
      addTearDown(server.close);

      expect((await server.get('/assets/nested/deep.txt')).body, 'deep');
    });

    test('answers HEAD without a body', () async {
      final server = await serve();
      addTearDown(server.close);

      final response = await server.send('HEAD', '/assets/hello.txt');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.bytes, isEmpty);
      expect(response.header('content-length'), '5');
    });

    test('answers 304 for an up to date conditional request', () async {
      final server = await serve();
      addTearDown(server.close);

      final first = await server.get('/assets/hello.txt');
      final lastModified = first.header('last-modified')!;

      final second = await server.get(
        '/assets/hello.txt',
        headers: {'if-modified-since': lastModified},
      );

      expect(second.statusCode, HttpStatus.notModified);
    });

    test('falls back to a binary content type for unknown extensions',
        () async {
      File('${public.path}/blob.weirdext').writeAsStringSync('data');

      final server = await serve();
      addTearDown(server.close);

      final response = await server.get('/assets/blob.weirdext');

      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.header('content-type'),
        contains('application/octet-stream'),
      );
    });

    test('serves the default document for the mount root', () async {
      final server = await serve(defaultDocument: 'index.html');
      addTearDown(server.close);

      expect((await server.get('/assets')).body, '<h1>home</h1>');
      expect((await server.get('/assets/')).body, '<h1>home</h1>');
    });

    test('answers 404 for a missing file', () async {
      final server = await serve();
      addTearDown(server.close);

      expect(
        (await server.get('/assets/nope.txt')).statusCode,
        HttpStatus.notFound,
      );
    });

    test('mounts nested under a parent route path', () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              '/api',
              routes: [
                HttpStaticRoute('files', directoryPath: public.path),
              ],
            ),
          ],
        ),
      );
      addTearDown(server.close);

      expect((await server.get('/api/files/hello.txt')).body, 'hello');
    });
  });

  group('path traversal', () {
    const attempts = [
      '/assets/../secret.txt',
      '/assets/%2e%2e/secret.txt',
      '/assets/..%2fsecret.txt',
      '/assets/%2e%2e%2fsecret.txt',
      r'/assets/..\secret.txt',
      '/assets/nested/../../secret.txt',
    ];

    for (final attempt in attempts) {
      test('refuses to escape the directory via $attempt', () async {
        final server = await serve();
        addTearDown(server.close);

        final response = await server.get(attempt);

        expect(response.statusCode, isNot(HttpStatus.ok));
        expect(response.body, isNot(contains('do-not-serve')));
      });
    }

    test('refuses a symlink pointing outside the directory', () async {
      Link('${public.path}/escape.txt')
          .createSync('${sandbox.path}/secret.txt');

      final server = await serve();
      addTearDown(server.close);

      final response = await server.get('/assets/escape.txt');

      expect(response.statusCode, HttpStatus.notFound);
      expect(response.body, isNot(contains('do-not-serve')));
    });

    test('a normalized traversal resolves to a route, never to the disk',
        () async {
      /// `Uri` applies RFC 3986 normalization before a request reaches a
      /// handler, so `%2e%2e` becomes `..` and the segment collapses. The
      /// request therefore lands on whatever route the normalized path names,
      /// which must never be a file outside a mount.
      final other = Directory('${sandbox.path}/other')..createSync();
      File('${other.path}/mounted.txt').writeAsStringSync('second mount');

      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpStaticRoute('/assets', directoryPath: public.path),
            HttpStaticRoute('/other', directoryPath: other.path),
          ],
        ),
      );
      addTearDown(server.close);

      /// Collapses to `/other/mounted.txt`, a legitimately mounted file.
      expect(
        (await server.get('/assets/%2e%2e/other/mounted.txt')).body,
        'second mount',
      );

      /// Collapses to `/secret.txt`, which no route serves.
      final escaped = await server.get('/assets/%2e%2e/secret.txt');
      expect(escaped.statusCode, HttpStatus.notFound);
      expect(escaped.body, isNot(contains('do-not-serve')));
    });

    test('does not leak into a sibling path with the same prefix', () async {
      final server = await serve();
      addTearDown(server.close);

      final response = await server.get('/assetsEVIL/hello.txt');

      expect(response.statusCode, HttpStatus.notFound);
      expect(response.body, isNot(contains('hello')));
    });
  });

  group('allowedExtensions', () {
    test('serves an allowed extension', () async {
      final server = await serve(allowedExtensions: {'png'});
      addTearDown(server.close);

      expect((await server.get('/assets/logo.png')).statusCode, HttpStatus.ok);
    });

    test('refuses an extension outside the list', () async {
      final server = await serve(allowedExtensions: {'png'});
      addTearDown(server.close);

      expect(
        (await server.get('/assets/hello.txt')).statusCode,
        HttpStatus.forbidden,
      );
    });

    test('accepts entries written with a leading dot or mixed case', () async {
      final server = await serve(allowedExtensions: {'.PNG'});
      addTearDown(server.close);

      expect((await server.get('/assets/logo.png')).statusCode, HttpStatus.ok);
    });

    test('refuses a dotfile, which has no extension', () async {
      final server = await serve(allowedExtensions: {'txt'});
      addTearDown(server.close);

      expect(
        (await server.get('/assets/.env')).statusCode,
        HttpStatus.forbidden,
      );
    });
  });

  group('directory listing', () {
    test('is disabled by default', () async {
      final server = await serve();
      addTearDown(server.close);

      expect((await server.get('/assets')).statusCode, HttpStatus.notFound);
    });

    test('lists entries and hides dotfiles', () async {
      final server = await serve(listDirectory: true);
      addTearDown(server.close);

      final response = await server.get('/assets');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, contains('hello.txt'));
      expect(response.body, contains('nested'));
      expect(response.body, isNot(contains('.env')));
    });

    test('escapes file names so they cannot inject markup', () async {
      File('${public.path}/<img src=x onerror=alert(1)>.txt')
          .writeAsStringSync('xss');

      final server = await serve(listDirectory: true);
      addTearDown(server.close);

      final response = await server.get('/assets');

      expect(response.body, isNot(contains('<img src=x')));
      expect(response.body, contains('&lt;img'));
    });

    test('links stay usable for names that need encoding', () async {
      File('${public.path}/my file.txt').writeAsStringSync('spaced');

      final server = await serve(listDirectory: true);
      addTearDown(server.close);

      expect((await server.get('/assets')).body, contains('my%20file.txt'));
      expect((await server.get('/assets/my%20file.txt')).body, 'spaced');
    });
  });
}
