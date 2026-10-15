part of 'lite_server.dart';

/// Per request body ceiling, published by [LiteServer] so the body readers can
/// enforce it without every handler having to pass it along.
final _maxBodySizes = Expando<int>('lite_server.maxRequestSize');

extension HttpResponseHelpers on HttpResponse {
  /// Writes [body] with status [code] and closes the response.
  ///
  /// When [body] is omitted, [message] becomes the body as well: HTTP reason
  /// phrases are dropped by HTTP/2 and are invisible to most clients, so a
  /// message that only lives there would never be seen.
  Future<void> status(
    int code, {
    Object? body,
    String? message,
    ContentType? contentType,
  }) async {
    statusCode = code;

    if (contentType != null) {
      headers.contentType = contentType;
    }

    if (message != null) {
      final sanitized = _HttpUtils.sanitizeReasonPhrase(message);

      if (sanitized.isNotEmpty) {
        reasonPhrase = sanitized;
      }
    }

    final payload = body ?? message;

    if (payload != null) {
      write(payload);
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

  /// Encodes [data] as JSON and closes the response.
  Future<void> json<T>(T data, {int code = HttpStatus.ok}) async {
    final encoded = utf8.encode(jsonEncode(data));

    statusCode = code;
    headers
      ..contentType = ContentType.json
      ..contentLength = encoded.length;

    add(encoded);

    await close();
  }

  Future<void> html(String data) {
    return ok(body: data, contentType: ContentType.html);
  }

  Future<void> text(String data, {int code = HttpStatus.ok}) {
    return status(code, body: data, contentType: ContentType.text);
  }

  Future<void> unauthorized({String? message}) async {
    await status(HttpStatus.unauthorized, message: message);
  }

  Future<void> forbidden({String? message}) async {
    await status(HttpStatus.forbidden, message: message);
  }

  Future<void> notFound({String? message}) async {
    await status(HttpStatus.notFound, message: message);
  }

  Future<void> methodNotAllowed({String? message}) async {
    await status(HttpStatus.methodNotAllowed, message: message);
  }

  Future<void> internalServerError({String? message}) async {
    await status(HttpStatus.internalServerError, message: message);
  }

  Future<void> badRequest([String? message]) async {
    await status(HttpStatus.badRequest, message: message);
  }

  /// Streams the file at [path] to the client.
  ///
  /// The file is piped instead of buffered, so serving a large file does not
  /// pull it into memory first.
  Future<void> file(String path, {String? mimeType}) async {
    final target = File(path);

    if (!target.existsSync()) {
      await notFound(message: 'File not found');
      return;
    }

    headers
      ..contentType = _HttpUtils.contentTypeFor(path, mimeType)
      ..contentLength = target.lengthSync();

    await target.openRead().pipe(this);
  }
}

extension HttpRequestHelpers on HttpRequest {
  /// Body ceiling for this request, taken from
  /// [LiteServer.maxRequestSize] when the request is served by a [LiteServer].
  int get maxBodySize =>
      _maxBodySizes[this] ?? LiteServer.defaultMaxRequestSize;

  /// Buffers the whole body.
  ///
  /// Throws [HttpRequestTooLargeException] as soon as the limit is passed, so
  /// a body that lies about (or omits) its `Content-Length` cannot exhaust
  /// memory. [LiteServer] turns that into a `413` response.
  Future<Uint8List> readBodyAsBytes({int? maxSize}) async {
    final limit = maxSize ?? maxBodySize;
    final builder = BytesBuilder(copy: false);

    await for (final chunk in this) {
      builder.add(chunk);

      if (builder.length > limit) {
        throw HttpRequestTooLargeException(limit);
      }
    }

    return builder.takeBytes();
  }

  /// Buffers the whole body and decodes it as text.
  ///
  /// [maxSize] overrides [maxBodySize] for this call.
  Future<String> readBodyAsString([Encoding? encoding, int? maxSize]) async {
    return (encoding ?? utf8).decode(await readBodyAsBytes(maxSize: maxSize));
  }

  /// Reads the body and decodes it as JSON.
  Future<T> readBodyAsJson<T>({int? maxSize}) async {
    final body = await readBodyAsBytes(maxSize: maxSize);
    return jsonDecode(utf8.decode(body)) as T;
  }

  /// Whether the body is a `multipart/*` payload with a boundary.
  bool get isMultipart {
    final contentType = headers.contentType;

    return contentType != null &&
        contentType.primaryType == 'multipart' &&
        contentType.parameters['boundary'] != null;
  }

  /// Streams the parts of a `multipart/*` body.
  ///
  /// Parts are yielded as they arrive and each one is collected through a
  /// [BytesBuilder], so a large upload no longer costs quadratic time in the
  /// number of chunks.
  Stream<HttpMultiPartData> multipartData({int? maxSize}) async* {
    final contentType = headers.contentType;

    if (contentType == null) {
      throw const HttpMultipartException('Content-Type header is missing');
    }

    final boundary = contentType.parameters['boundary'];

    if (boundary == null || boundary.isEmpty) {
      throw const HttpMultipartException('Content-Type has no boundary');
    }

    if (boundary.length > 70) {
      throw const HttpMultipartException('Boundary exceeds 70 characters');
    }

    final limit = maxSize ?? maxBodySize;
    var total = 0;

    final parts = MimeMultipartTransformer(boundary).bind(this);

    await for (final part in parts) {
      final partHeaders = Map<String, String>.from(part.headers);
      final contentDisposition = partHeaders.remove('content-disposition');
      final builder = BytesBuilder(copy: false);

      await for (final chunk in part) {
        total += chunk.length;

        if (total > limit) {
          throw HttpRequestTooLargeException(limit);
        }

        builder.add(chunk);
      }

      yield HttpMultiPartData(
        {
          ...parseContentDisposition(contentDisposition),
          ...partHeaders,
        },
        builder.takeBytes(),
      );
    }
  }

  /// Parses a `content-disposition` value into its lower cased parameters.
  ///
  /// Values are split on their first `=` only, so a quoted value that itself
  /// contains `=` survives intact.
  Map<String, String> parseContentDisposition(String? contentDisposition) {
    final output = <String, String>{};

    if (contentDisposition == null || contentDisposition.length > 1000) {
      return output;
    }

    final params = <String>[];

    for (final entry in contentDisposition.split(';')) {
      final separator = entry.indexOf('=');

      if (separator == -1) {
        final param = entry.trim();

        if (param.isNotEmpty) {
          params.add(param);
        }

        continue;
      }

      final key = entry.substring(0, separator).trim().toLowerCase();
      final value = entry.substring(separator + 1).trim();

      output[key] =
          value.length > 1 && value.startsWith('"') && value.endsWith('"')
              ? value.substring(1, value.length - 1)
              : value;
    }

    output['params'] = params.join(',');

    return output;
  }
}

/// One part of a `multipart/*` request body.
class HttpMultiPartData {
  const HttpMultiPartData(this.info, this.bytes);

  /// Merged `content-disposition` parameters and part headers.
  final Map<String, String> info;

  /// Raw part payload.
  final List<int> bytes;

  /// Form field name, when the part declares one.
  String? get name => info['name'];

  /// File name, when the part is a file upload.
  String? get filename => info['filename'];

  /// Media type declared for the part.
  String? get contentType => info['content-type'];

  /// Whether the part carries a file rather than a plain form field.
  bool get isFile => info.containsKey('filename');

  /// Decodes [bytes] as text.
  String text([Encoding encoding = utf8]) => encoding.decode(bytes);
}
