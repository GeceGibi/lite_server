part of 'lite_server.dart';

class _HttpRouteMapper {
  const _HttpRouteMapper(this.route, this.controllers);
  final HttpRoute route;
  final List<HttpController> controllers;
}

class HttpRoutePayload {
  HttpRoutePayload({
    this.pathParameters = const {},
    this.extras = const {},
  });

  final Map<String, String> pathParameters;
  final Map<String, Object?> extras;
}
