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
  }) : super(
          handler: (request, payload) {
            final dir = Directory(directoryPath);

            var fileName = request.uri.path.substring(path.length);

            if (fileName.startsWith('/')) {
              fileName = fileName.substring(1);
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

            final mimeType = lookupMimeType('${dir.path}/$fileName');

            if (mimeType == null) {
              request.response.internalServerError(
                message: 'Mime-Type not found',
              );
              return;
            }

            final bytes = file.readAsBytesSync();

            request.response.headers.contentLength = bytes.length;
            request.response.headers.contentType = ContentType.parse(mimeType);

            request.response.add(file.readAsBytesSync());
            request.response.close();
          },
        );

  static String _getListDirectoryHtml(List<String> items) {
    final li = [for (final item in items) '<li><a href="$item">$item</a></li>'];
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title></title></head><body><ul>${li.join()}</ul></body></html>';
  }
}
