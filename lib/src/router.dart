part of 'lite_server.dart';

///! ---------------------------------------------------------------------------
class HttpRoute {
  const HttpRoute(
    this.path, {
    required this.methods,
    this.handler,
    this.controllers,
    this.routes,
  });

  const HttpRoute.get(
    this.path, {
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'GET'};

  const HttpRoute.post(
    this.path, {
    this.handler,
    this.controllers,
    this.routes,
  }) : methods = const {'POST'};

  const HttpRoute.all(
    this.path, {
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

  final String path;
  final Set<String> methods;
  final FutureOr<void> Function(HttpRequest request, HttpRoutePayload payload)?
      handler;

  final List<HttpRoute>? routes;
  final List<HttpController>? controllers;
}

///! ---------------------------------------------------------------------------

class HttpStaticRoute extends HttpRoute {
  HttpStaticRoute(
    super.path, {
    required String directoryPath,
    super.methods = const {'GET'},
    super.controllers,
    String? defaultDocument,
    bool listDirectory = false,
    List<String> allowedExtensions = const [],
  }) : super(
          handler: (request, payload) {
            final dir = Directory(directoryPath);

            // Security check - prevent directory traversal
            var fileName = request.uri.path.substring(path.length);
            if (fileName.startsWith('/')) {
              fileName = fileName.substring(1);
            }

            // Prevent directory traversal attacks
            if (fileName.contains('..') || fileName.contains('//')) {
              request.response.forbidden();
              return;
            }

            if (fileName.isEmpty) {
              if (defaultDocument != null) {
                fileName = defaultDocument;
              }

              /// ls
              else if (listDirectory) {
                final files = dir.listSync().where((element) {
                  return element.statSync().type == FileSystemEntityType.file;
                });

                final content = [
                  for (final element in files)
                    '$path/${element.path.split('/').last}',
                ];

                request.response.ok(
                  body: _getListDirectoryHtml(content),
                  contentType: ContentType.html,
                );
                return;
              }
            }

            final file = File('${dir.path}/$fileName');

            if (!file.existsSync()) {
              request.response.notFound();
              return;
            }

            // Check file extension if restrictions are set
            if (allowedExtensions.isNotEmpty) {
              final extension = fileName.split('.').last.toLowerCase();
              if (!allowedExtensions.contains(extension)) {
                request.response.forbidden();
                return;
              }
            }

            final mimeType = lookupMimeType('${dir.path}/$fileName');

            if (mimeType == null) {
              request.response.internalServerError(
                message: 'Mime-Type not found',
              );
              return;
            }

            try {
              final bytes = file.readAsBytesSync();

              request.response.headers.contentLength = bytes.length;
              request.response.headers.contentType =
                  ContentType.parse(mimeType);

              request.response.add(bytes);
              request.response.close();
            } catch (e) {
              request.response.internalServerError(
                message: 'Error reading file',
              );
            }
          },
        );

  static String _getListDirectoryHtml(List<String> items) {
    final li = [for (final item in items) '<li><a href="$item">$item</a></li>'];
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Directory Listing</title><style>body{font-family:Arial,sans-serif;margin:40px;background:#f5f5f5}ul{list-style:none;padding:0}li{margin:5px 0}li a{text-decoration:none;color:#0066cc;padding:8px 12px;background:white;border-radius:4px;display:inline-block;box-shadow:0 1px 3px rgba(0,0,0,0.1)}li a:hover{background:#f0f0f0}</style></head><body><h1>Directory Listing</h1><ul>${li.join()}</ul></body></html>';
  }
}
