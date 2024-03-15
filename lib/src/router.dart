part of 'lite_server.dart';

class HttpRoutePayload {
  HttpRoutePayload({
    this.pathParameters = const {},
    this.extras = const {},
  });

  final Map<String, String> pathParameters;
  final Map<String, Object?> extras;
}

///! ---------------------------------------------------------------------------
class HttpRoute {
  const HttpRoute(
    this.path, {
    required this.methods,
    this.handler,
    this.services,
    this.routes,
  });

  const HttpRoute.get(
    this.path, {
    this.handler,
    this.services,
    this.routes,
  }) : methods = const {'GET'};

  const HttpRoute.post(
    this.path, {
    this.handler,
    this.services,
    this.routes,
  }) : methods = const {'POST'};

  const HttpRoute.all(
    this.path, {
    this.handler,
    this.services,
    this.routes,
  }) : methods = const {
          'POST',
          'GET',
          'OPTIONS',
          'HEAD',
          'PATCH',
          'DELETE',
          'PUT'
        };

  final String path;
  final Set<String> methods;
  final void Function(HttpRequest request, HttpRoutePayload payload)? handler;

  final List<HttpRoute>? routes;
  final List<HttpService>? services;
}

///! ---------------------------------------------------------------------------

class HttpStaticRoute extends HttpRoute {
  HttpStaticRoute(
    super.path, {
    super.methods = const {'GET'},
    required String directoryPath,
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
                final content = [
                  for (var element in dir.listSync())
                    '$path/${element.path.split('/').last}',
                ];

                request.response.headers.contentType = ContentType.html;
                request.response.write(_getListDirectoryHtml(content));
                request.response.close();
                return;
              }
            }

            final file = File('${dir.path}/$fileName');

            if (!file.existsSync()) {
              request.response.statusCode = HttpStatus.notFound;
              request.response.close();
              return;
            }

            final bytes = file.readAsBytesSync();
            final mimeType = lookupMimeType('${dir.path}/$fileName');

            if (mimeType == null) {
              request.response.statusCode = HttpStatus.internalServerError;
              request.response.reasonPhrase = 'Mime-Type not found';
              request.response.close();
              return;
            }

            request.response.headers.contentLength = bytes.length;
            request.response.headers.contentType = ContentType.parse(mimeType);

            request.response.add(file.readAsBytesSync());
            request.response.close();
          },
        );

  static String _getListDirectoryHtml(List<String> items) {
    final li = [for (final item in items) '<li><a href="$item">$item</a></li>'];
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title></title></head><body><ul>${li.join('')}</ul></body></html>';
  }
}
