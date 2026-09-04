import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

/// A [LiteServer] bound to an ephemeral loopback port for the duration of a
/// test, plus the helpers needed to talk to it.
class TestServer {
  TestServer._(this._server, this._httpServer, this._client);

  final LiteServer _server;
  final HttpServer _httpServer;
  final HttpClient _client;

  static Future<TestServer> start(
    LiteServer server, {
    List<HttpController> controllers = const [],
    void Function(HttpRequest request, Object? error, StackTrace stackTrace)?
        onError,
  }) async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen(
      httpServer,
      controllers: controllers,
      onError: onError,
      logStartup: false,
    );

    return TestServer._(server, httpServer, HttpClient());
  }

  LiteServer get liteServer => _server;

  Uri uri(String path) =>
      Uri.parse('http://127.0.0.1:${_httpServer.port}$path');

  Future<TestResponse> send(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    bool chunked = false,
  }) async {
    final request = await _client.openUrl(method, uri(path));

    headers.forEach(request.headers.set);

    if (body != null) {
      if (chunked) {
        request.headers.chunkedTransferEncoding = true;
      }

      if (body is List<int>) {
        request.add(body);
      } else {
        request.write(body);
      }
    }

    final response = await request.close();
    final bytes = await response
        .fold<List<int>>(<int>[], (previous, chunk) => previous..addAll(chunk));

    return TestResponse(response, bytes);
  }

  Future<TestResponse> get(
    String path, {
    Map<String, String> headers = const {},
  }) {
    return send('GET', path, headers: headers);
  }

  Future<void> close() async {
    _client.close(force: true);
    await _httpServer.close(force: true);
  }
}

class TestResponse {
  TestResponse(this._response, this.bytes);

  final HttpClientResponse _response;
  final List<int> bytes;

  int get statusCode => _response.statusCode;
  String get body => utf8.decode(bytes, allowMalformed: true);
  HttpHeaders get headers => _response.headers;

  Object? get json => jsonDecode(body);

  String? header(String name) => _response.headers.value(name);
}

/// Builds a `multipart/form-data` body together with its content type.
({List<int> body, String contentType}) buildMultipart(
  List<({String name, String? filename, String? contentType, String value})>
      parts, {
  String boundary = 'lite-server-boundary',
}) {
  final buffer = StringBuffer();

  for (final part in parts) {
    buffer
      ..write('--$boundary\r\n')
      ..write('content-disposition: form-data; name="${part.name}"');

    if (part.filename != null) {
      buffer.write('; filename="${part.filename}"');
    }

    buffer.write('\r\n');

    if (part.contentType != null) {
      buffer.write('content-type: ${part.contentType}\r\n');
    }

    buffer
      ..write('\r\n')
      ..write(part.value)
      ..write('\r\n');
  }

  buffer.write('--$boundary--\r\n');

  return (
    body: utf8.encode(buffer.toString()),
    contentType: 'multipart/form-data; boundary=$boundary',
  );
}
