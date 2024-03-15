part of 'lite_server.dart';

class _HttpRouteMapper {
  const _HttpRouteMapper(this.route, this.services);
  final HttpRoute route;
  final List<HttpService> services;
}

class HttpRequestError {
  const HttpRequestError(this.request, this.error, this.stackTrace);
  final HttpRequest request;
  final Object? error;
  final StackTrace stackTrace;
}

class HttpRoutePayload {
  HttpRoutePayload({
    this.pathParameters = const {},
    this.extras = const {},
  });

  final Map<String, String> pathParameters;
  final Map<String, Object?> extras;
}
