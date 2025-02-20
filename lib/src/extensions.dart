part of 'lite_server.dart';

extension HttpResponseHelpers on HttpResponse {
  Future<void> status(
    int code, {
    Object? body,
    String? message,
    ContentType? contentType,
  }) async {
    headers.contentType = contentType;
    statusCode = code;

    if (message != null) {
      reasonPhrase = message;
    }

    if (body != null) {
      write(body);
    }

    await close();
  }

  Future<void> ok({
    Object? body,
    String? message,
    ContentType? contentType,
  }) async {
    await status(
      HttpStatus.ok,
      body: body,
      message: message,
      contentType: contentType,
    );
  }

  Future<void> json<T>(T data) async {
    headers.contentType = ContentType.json;
    write(jsonEncode(data));
    await close();
  }

  Future<void> html(String data) {
    return ok(body: data, contentType: ContentType.html);
  }

  Future<void> unauthorized() async {
    await status(HttpStatus.unauthorized);
  }

  Future<void> notFound() async {
    await status(HttpStatus.notFound);
  }

  Future<void> methodNotAllowed() async {
    await status(HttpStatus.methodNotAllowed);
  }

  Future<void> internalServerError({String? message}) async {
    await status(HttpStatus.internalServerError, message: message);
  }

  Future<void> badRequest([String? message]) async {
    await status(HttpStatus.badRequest, message: message);
  }

  Future<void> file(String path, {String? mimeType}) async {
    final bytes = File(path).readAsBytesSync();
    final mime = mimeType ?? lookupMimeType(path);

    if (mime == null) {
      return internalServerError(message: "mime-type can't resolved.");
    }

    headers
      ..contentLength = bytes.length
      ..set('content-type', mime);

    add(bytes);

    await close();
  }
}

extension HttpRequestHelpers on HttpRequest {
  Future<String> readBodyAsString([Encoding? encoding]) async {
    final encoder = encoding ?? utf8;
    return encoder.decode((await toList()).expand((i) => i).toList());
  }

  bool get isMultipart {
    if (headers.contentType == null) {
      return false;
    }

    return headers.contentType!.parameters['boundary'] != null;
  }

  Stream<HttpMultiPartData> multipartData() async* {
    if (headers.contentType == null) {
      throw Exception('Content-Type not found');
    }

    final boundary = headers.contentType!.parameters['boundary'];

    if (boundary == null) {
      throw Exception('Boundary not found');
    }

    final transformer = MimeMultipartTransformer(boundary);
    final parts = await transform<MimeMultipart>(transformer.cast()).toList();

    for (final part in parts) {
      final contentDisposition = part.headers['content-disposition'];
      part.headers.remove('content-disposition');

      yield HttpMultiPartData(
        {
          ...parseContentDisposition(contentDisposition),
          ...part.headers,
        },
        await part.fold<List<int>>([], (p, d) => [...p, ...d]),
      );
    }
  }

  Map<String, String> parseContentDisposition(String? contentDisposition) {
    final output = <String, String>{};
    final pattern = RegExp('"(.+)"');

    if (contentDisposition == null) {
      return output;
    }

    final params = <String>[];

    for (final entry in contentDisposition.split(';')) {
      if (entry.contains('=')) {
        final parsed = entry.split('=');
        final key = parsed.first.trim();

        if (pattern.hasMatch(parsed.last)) {
          output[key] = pattern.firstMatch(parsed.last)!.group(1)!;
        } else {
          output[key] = parsed.last.trim();
        }
      } else {
        params.add(entry);
      }
    }

    output['params'] = params.join(',');

    return output;
  }
}

class HttpMultiPartData {
  const HttpMultiPartData(this.info, this.bytes);
  final Map<String, String> info;
  final List<int> bytes;
}
