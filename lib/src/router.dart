part of 'lite_server.dart';

///! ---------------------------------------------------------------------------
class HttpRoute {
  const HttpRoute({
    required this.path,
    required this.methods,
    this.handler,
    this.controllers,
    this.routes,
  });

  const HttpRoute.get({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'GET'};

  const HttpRoute.post({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'POST'};

  const HttpRoute.put({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'PUT'};

  const HttpRoute.patch({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'PATCH'};

  const HttpRoute.delete({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'DELETE'};

  const HttpRoute.head({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'HEAD'};

  const HttpRoute.options({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'OPTIONS'};

  const HttpRoute.all({
    required this.path,
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {
          'POST',
          'GET',
          'OPTIONS',
          'HEAD',
          'PATCH',
          'DELETE',
          'PUT',
        };

  /// Absolute path for top level routes (`/users`), relative for nested ones
  /// (`users`). May contain `<name>` placeholders.
  final String path;

  /// Methods this route answers. Matching is case insensitive.
  final Set<String> methods;

  final FutureOr<void> Function(HttpRequest request, HttpRoutePayload payload)?
      handler;

  /// Nested routes, appended to [path]. A route without a [handler] acts as a
  /// grouping node for its [routes].
  final List<HttpRoute>? routes;

  /// Controllers that run for this route and every route nested under it.
  final List<HttpController>? controllers;
}

///! ---------------------------------------------------------------------------

/// Serves the contents of a directory under the route path.
///
/// The request path is decoded segment by segment and every segment is
/// validated, so `..`, `%2e%2e`, `%2f` and backslashes cannot be used to reach
/// files outside the directory. Resolved files are additionally checked against
/// the real directory path, which also blocks symlinks pointing outside of it.
class HttpStaticRoute extends HttpRoute {
  HttpStaticRoute({
    required super.path,
    required String directoryPath,
    super.methods = const {'GET', 'HEAD'},
    super.controllers,
    String? defaultDocument,
    bool listDirectory = false,
    Set<String> allowedExtensions = const {},
  }) : super(
          handler: (request, payload) => _serve(
            request,
            mountPath: payload.path,
            directory: Directory(directoryPath),
            defaultDocument: defaultDocument,
            listDirectory: listDirectory,
            allowedExtensions: [
              for (final extension in allowedExtensions)
                extension.toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
            ],
          ),
        );

  static Future<void> _serve(
    HttpRequest request, {
    required String mountPath,
    required Directory directory,
    required String? defaultDocument,
    required bool listDirectory,
    required List<String> allowedExtensions,
  }) async {
    if (!directory.existsSync()) {
      await request.response.internalServerError(
        message: 'Static directory does not exist',
      );
      return;
    }

    final segments = _relativeSegments(request.uri.path, mountPath);

    if (segments == null) {
      await request.response.forbidden(message: 'Invalid path');
      return;
    }

    var relative = segments.join('/');
    var target =
        relative.isEmpty ? directory.path : '${directory.path}/$relative';

    if (FileSystemEntity.isDirectorySync(target)) {
      if (defaultDocument != null) {
        relative =
            relative.isEmpty ? defaultDocument : '$relative/$defaultDocument';
        target = '${directory.path}/$relative';
      } else if (listDirectory) {
        await _listDirectory(request, Directory(target), mountPath, segments);
        return;
      } else {
        /// Answer as if nothing is there rather than confirming the directory.
        await request.response.notFound(message: 'Not found');
        return;
      }
    }

    if (allowedExtensions.isNotEmpty &&
        !allowedExtensions.contains(_HttpUtils.extensionOf(relative))) {
      await request.response.forbidden(message: 'File type not allowed');
      return;
    }

    final file = File(target);

    if (!file.existsSync() || !_isInside(file, directory)) {
      await request.response.notFound(message: 'File not found');
      return;
    }

    await _sendFile(request, file);
  }

  /// Splits the part of [requestPath] below [mountPath] into decoded segments.
  ///
  /// Returns `null` as soon as a segment could escape the mount point, so the
  /// caller can reject the request without touching the file system.
  static List<String>? _relativeSegments(
    String requestPath,
    String mountPath,
  ) {
    var relative = _HttpUtils.normalizeRequestPath(requestPath);

    if (mountPath != '/' && relative.startsWith(mountPath)) {
      relative = relative.substring(mountPath.length);
    }

    final segments = <String>[];

    for (final raw in relative.split('/')) {
      if (raw.isEmpty) {
        continue;
      }

      final segment = _HttpUtils.decodeSegment(raw);

      if (segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains(r'\') ||
          segment.contains('\u0000')) {
        return null;
      }

      segments.add(segment);
    }

    return segments;
  }

  /// Whether [entity] really lives inside [root] once symlinks are resolved.
  static bool _isInside(FileSystemEntity entity, Directory root) {
    try {
      final rootPath = root.resolveSymbolicLinksSync();
      final entityPath = entity.resolveSymbolicLinksSync();

      return entityPath == rootPath ||
          entityPath.startsWith('$rootPath${Platform.pathSeparator}');
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _sendFile(HttpRequest request, File file) async {
    final stat = file.statSync();
    final modified = stat.modified.toUtc();

    // `Last-Modified` only has second precision, so drop anything below it
    // before comparing or every conditional request would miss.
    final lastModified = modified.subtract(
      Duration(
        milliseconds: modified.millisecond,
        microseconds: modified.microsecond,
      ),
    );

    final ifModifiedSince = request.headers.ifModifiedSince;

    if (ifModifiedSince != null && !lastModified.isAfter(ifModifiedSince)) {
      request.response.statusCode = HttpStatus.notModified;
      await request.response.close();
      return;
    }

    request.response.headers
      ..contentType = _HttpUtils.contentTypeFor(file.path)
      ..contentLength = stat.size
      ..set(HttpHeaders.lastModifiedHeader, HttpDate.format(lastModified));

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    try {
      await file.openRead().pipe(request.response);
    } on FileSystemException {
      // Headers are already on the wire, so closing early is the only signal
      // left for the client.
      await request.response.close();
    }
  }

  static Future<void> _listDirectory(
    HttpRequest request,
    Directory directory,
    String mountPath,
    List<String> segments,
  ) async {
    final prefix = [
      if (mountPath != '/') mountPath,
      ...segments.map(Uri.encodeComponent),
    ].join('/');

    final entities = directory.listSync(followLinks: false)
      ..sort((a, b) {
        if ((a is Directory) != (b is Directory)) {
          return a is Directory ? -1 : 1;
        }

        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

    final items = <String>[];

    for (final entity in entities) {
      final name = _HttpUtils.basename(entity.path);

      // Hidden entries such as `.env` or `.git` stay hidden.
      if (name.isEmpty || name.startsWith('.')) {
        continue;
      }

      final isDirectory = entity is Directory;
      final label = isDirectory ? '$name/' : name;
      final href = '$prefix/${Uri.encodeComponent(name)}';

      items.add(
        '<li><a href="${_HttpUtils.escapeHtml(href)}">'
        '${_HttpUtils.escapeHtml(label)}</a></li>',
      );
    }

    await request.response.ok(
      body: _getListDirectoryHtml(prefix.isEmpty ? '/' : prefix, items),
      contentType: ContentType.html,
    );
  }

  static String _getListDirectoryHtml(String title, List<String> items) {
    final body =
        items.isEmpty ? '<p>Empty directory</p>' : '<ul>${items.join()}</ul>';

    final buffer = StringBuffer()
      ..write('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">')
      ..write('<meta name="viewport" content="width=device-width,')
      ..write(' initial-scale=1.0"><title>Directory Listing</title>')
      ..write(_listDirectoryStyle)
      ..write('</head><body><h1>')
      ..write(_HttpUtils.escapeHtml(title))
      ..write('</h1>')
      ..write(body)
      ..write('</body></html>');

    return buffer.toString();
  }

  static const _listDirectoryStyle =
      '<style>body{font-family:Arial,sans-serif;margin:40px;background:#f5f5f5}ul{list-style:none;padding:0}li{margin:5px 0}li a{text-decoration:none;color:#0066cc;padding:8px 12px;background:white;border-radius:4px;display:inline-block;box-shadow:0 1px 3px rgba(0,0,0,0.1)}li a:hover{background:#f0f0f0}</style>';
}
