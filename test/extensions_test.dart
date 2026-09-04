import 'dart:convert';
import 'dart:io';

import 'package:lite_server/lite_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('response helpers', () {
    late TestServer server;

    setUpAll(() async {
      server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              '/json',
              handler: (request, payload) =>
                  request.response.json({'name': 'ünïcödé'}),
            ),
            HttpRoute.get(
              '/json-created',
              handler: (request, payload) => request.response.json(
                {'id': 1},
                code: HttpStatus.created,
              ),
            ),
            HttpRoute.get(
              '/text',
              handler: (request, payload) => request.response.text('plain'),
            ),
            HttpRoute.get(
              '/html',
              handler: (request, payload) => request.response.html('<b>hi</b>'),
            ),
            HttpRoute.get(
              '/message-only',
              handler: (request, payload) =>
                  request.response.badRequest('missing field'),
            ),
            HttpRoute.get(
              '/injected',
              handler: (request, payload) => request.response.status(
                HttpStatus.badRequest,
                message: 'bad\r\nx-injected: yes',
              ),
            ),
            HttpRoute.get(
              '/keeps-content-type',
              handler: (request, payload) {
                request.response.headers.contentType = ContentType.html;
                return request.response.status(HttpStatus.ok, body: '<i>x</i>');
              },
            ),
            HttpRoute.get(
              '/missing-file',
              handler: (request, payload) =>
                  request.response.file('does/not/exist.txt'),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => server.close());

    test('json sets the content type and a byte accurate length', () async {
      final response = await server.get('/json');

      expect(response.json, {'name': 'ünïcödé'});
      expect(response.header('content-type'), contains('application/json'));
      expect(
        response.header('content-length'),
        utf8.encode(response.body).length.toString(),
      );
    });

    test('json accepts a status code', () async {
      expect(
        (await server.get('/json-created')).statusCode,
        HttpStatus.created,
      );
    });

    test('text and html set their content types', () async {
      expect(
        (await server.get('/text')).header('content-type'),
        contains('text/plain'),
      );
      expect(
        (await server.get('/html')).header('content-type'),
        contains('text/html'),
      );
    });

    test('a message without a body is sent as the body', () async {
      final response = await server.get('/message-only');

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body, 'missing field');
    });

    test('a message cannot inject a header into the status line', () async {
      final response = await server.get('/injected');

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.header('x-injected'), isNull);
      expect(response.headers['x-injected'], isNull);
    });

    test('status keeps a content type set earlier', () async {
      final response = await server.get('/keeps-content-type');

      expect(response.header('content-type'), contains('text/html'));
    });

    test('file answers 404 instead of throwing when it is missing', () async {
      expect(
        (await server.get('/missing-file')).statusCode,
        HttpStatus.notFound,
      );
    });

    test('file streams an existing file', () async {
      final directory = Directory.systemTemp.createTempSync('lite_server_file');
      addTearDown(() => directory.deleteSync(recursive: true));

      final target = File('${directory.path}/data.txt')
        ..writeAsStringSync('streamed');

      final local = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.get(
              '/f',
              handler: (request, payload) => request.response.file(target.path),
            ),
          ],
        ),
      );
      addTearDown(local.close);

      final response = await local.get('/f');

      expect(response.body, 'streamed');
      expect(response.header('content-length'), '8');
    });
  });

  group('request helpers', () {
    test('readBodyAsJson decodes the body', () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.post(
              '/in',
              handler: (request, payload) async {
                final data =
                    await request.readBodyAsJson<Map<String, Object?>>();
                await request.response.json({'echo': data['value']});
              },
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final response = await server.send(
        'POST',
        '/in',
        body: '{"value": 42}',
        headers: {'content-type': 'application/json'},
      );

      expect(response.json, {'echo': 42});
    });

    test('isMultipart only accepts a multipart content type', () async {
      final server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.post(
              '/probe',
              handler: (request, payload) =>
                  request.response.json({'multipart': request.isMultipart}),
            ),
          ],
        ),
      );
      addTearDown(server.close);

      final form = buildMultipart([
        (name: 'a', filename: null, contentType: null, value: '1'),
      ]);

      expect(
        (await server.send(
          'POST',
          '/probe',
          body: form.body,
          headers: {'content-type': form.contentType},
        ))
            .json,
        {'multipart': true},
      );

      expect(
        (await server.send(
          'POST',
          '/probe',
          body: 'x',
          headers: {'content-type': 'text/plain; boundary=fake'},
        ))
            .json,
        {'multipart': false},
      );
    });
  });

  group('multipart', () {
    late TestServer server;

    setUpAll(() async {
      server = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.post(
              '/upload',
              handler: (request, payload) async {
                final parts = <Map<String, Object?>>[];

                await for (final part in request.multipartData()) {
                  parts.add({
                    'name': part.name,
                    'filename': part.filename,
                    'contentType': part.contentType,
                    'isFile': part.isFile,
                    'size': part.bytes.length,
                    'text': part.text(),
                  });
                }

                await request.response.json(parts);
              },
            ),
          ],
        ),
      );
    });

    tearDownAll(() => server.close());

    Future<TestResponse> upload(
      List<({String name, String? filename, String? contentType, String value})>
          parts,
    ) {
      final form = buildMultipart(parts);

      return server.send(
        'POST',
        '/upload',
        body: form.body,
        headers: {'content-type': form.contentType},
      );
    }

    test('exposes field name, file name and content type', () async {
      final response = await upload([
        (name: 'title', filename: null, contentType: null, value: 'hello'),
        (
          name: 'doc',
          filename: 'notes.txt',
          contentType: 'text/plain',
          value: 'body'
        ),
      ]);

      expect(response.json, [
        {
          'name': 'title',
          'filename': null,
          'contentType': null,
          'isFile': false,
          'size': 5,
          'text': 'hello',
        },
        {
          'name': 'doc',
          'filename': 'notes.txt',
          'contentType': 'text/plain',
          'isFile': true,
          'size': 4,
          'text': 'body',
        },
      ]);
    });

    test('keeps a file name that contains an equals sign', () async {
      final response = await upload([
        (name: 'doc', filename: 'a=b.txt', contentType: null, value: 'x'),
      ]);

      expect(
        (response.json! as List).single,
        containsPair('filename', 'a=b.txt'),
      );
    });

    test('reassembles a payload split across many chunks', () async {
      final response = await upload([
        (
          name: 'blob',
          filename: 'big.bin',
          contentType: 'application/octet-stream',
          value: 'A' * 400000
        ),
      ]);

      expect(
        (response.json! as List).single,
        containsPair('size', 400000),
      );
    });

    test('rejects a body over the configured limit', () async {
      final small = await TestServer.start(
        LiteServer(
          maxRequestSize: 512,
          routes: [
            HttpRoute.post(
              '/upload',
              handler: (request, payload) async {
                await request.multipartData().drain<void>();
                await request.response.ok();
              },
            ),
          ],
        ),
      );
      addTearDown(small.close);

      final form = buildMultipart([
        (
          name: 'blob',
          filename: 'big.bin',
          contentType: null,
          value: 'A' * 5000
        ),
      ]);

      final response = await small.send(
        'POST',
        '/upload',
        body: form.body,
        headers: {'content-type': form.contentType},
        chunked: true,
      );

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('reports a missing boundary instead of hanging', () async {
      final plain = await TestServer.start(
        LiteServer(
          routes: [
            HttpRoute.post(
              '/upload',
              handler: (request, payload) async {
                await request.multipartData().drain<void>();
                await request.response.ok();
              },
            ),
          ],
        ),
      );
      addTearDown(plain.close);

      final response = await plain.send(
        'POST',
        '/upload',
        body: 'x',
        headers: {'content-type': 'multipart/form-data'},
      );

      expect(response.statusCode, HttpStatus.internalServerError);
    });
  });
}
