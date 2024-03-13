part of 'lite_server.dart';

class HttpRoutePayload {
  HttpRoutePayload({
    this.pathParameters = const {},
    this.extras = const {},
  });

  final Map<String, String> pathParameters;
  final Map<String, Object?> extras;
}

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
  final void Function(HttpRequest, HttpRoutePayload)? handler;

  final List<HttpRoute>? routes;
  final List<HttpService>? services;
}
