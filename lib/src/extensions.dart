part of 'lite_server.dart';

extension HttpResponseHelpers on HttpResponse {
  Future<void> ok(Object? body, {ContentType? contentType}) async {
    headers.contentType = contentType ?? ContentType.text;
    write(body);
    await close();
  }

  Future<void> status(int code, {String? message}) async {
    statusCode = code;

    if (message != null) {
      reasonPhrase = message;
    }

    await close();
  }

  Future<void> json<T>(T data) async {
    headers.contentType = ContentType.json;
    write(jsonEncode(data));
    await close();
  }

  /// Default content type = ContentType.text
  Future<void> text(String data, {ContentType? contentType}) async {
    headers.contentType = contentType ?? ContentType.text;
    write(data);
    await close();
  }

  Future<void> html(String data) async {
    headers.contentType = ContentType.html;
    write(data);
    await close();
  }

  Future<void> unauthorized() async {
    statusCode = HttpStatus.unauthorized;
    await close();
  }

  Future<void> badRequest([String? message]) async {
    statusCode = HttpStatus.badRequest;

    if (message != null) {
      reasonPhrase = message;
    }

    await close();
  }

  Future<void> file(String path, {String? mimeType}) async {
    final bytes = File(path).readAsBytesSync();
    final mime = mimeType ?? lookupMimeType(path);

    if (mime == null) {
      statusCode = HttpStatus.internalServerError;
      reasonPhrase = 'Mime-Type can\'t resolved.';
      await close();
      return;
    }

    headers.contentLength = bytes.length;
    headers.set('content-type', mime);

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
    final pattern = RegExp(r'"(.+)"');

    if (contentDisposition == null) {
      return output;
    }

    var params = <String>[];

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
