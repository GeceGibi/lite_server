part of 'lite_server.dart';

extension HttpResponseHelpers on HttpResponse {
  HttpResponse ok(Object? body, {ContentType? contentType}) {
    headers.contentType = contentType ?? ContentType.text;
    write(body);
    return this;
  }

  HttpResponse status(int code) {
    statusCode = code;
    return this;
  }

  HttpResponse json<T>(T data) {
    headers.contentType = ContentType.json;
    write(jsonEncode(data));
    return this;
  }

  /// Default content type = ContentType.text
  HttpResponse text(String data, {ContentType? contentType}) {
    headers.contentType = contentType ?? ContentType.text;
    write(data);
    return this;
  }

  HttpResponse html(String data) {
    headers.contentType = ContentType.html;
    write(data);
    return this;
  }

  HttpResponse unauthorized() {
    statusCode = HttpStatus.unauthorized;
    return this;
  }

  HttpResponse badRequest([String? message]) {
    statusCode = HttpStatus.badRequest;

    if (message != null) {
      reasonPhrase = message;
    }

    return this;
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
