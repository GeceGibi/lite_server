part of 'lite_server.dart';

/// A route flattened to its absolute path, together with every controller it
/// inherited from its ancestors.
///
/// The path pattern and the upper cased method set are computed once here so
/// request handling never has to build a [RegExp] per request.
class _HttpRouteMapper {
  _HttpRouteMapper(this.route, this.controllers, this.path)
      : isStaticFileRoute = route is HttpStaticRoute,
        methods = {
          for (final method in route.methods) method.toUpperCase(),
        },
        _compiled = _HttpUtils.compile(path);

  final HttpRoute route;
  final List<HttpController> controllers;
  final String path;
  final Set<String> methods;
  final bool isStaticFileRoute;

  final (RegExp?, List<String>) _compiled;

  RegExp? get pattern => _compiled.$1;
  List<String> get parameterNames => _compiled.$2;

  /// Whether the path contains at least one `<parameter>` placeholder.
  bool get isDynamic => _compiled.$1 != null;
}

/// Outcome of resolving a request against the route table.
class _RouteResolution {
  const _RouteResolution({
    this.mapper,
    this.pathParameters = const {},
    this.allowedMethods = const {},
  });

  /// The route that will handle the request, or `null` when nothing matched.
  final _HttpRouteMapper? mapper;

  final Map<String, String> pathParameters;

  /// Methods registered for a path that matched while [mapper] is `null`, used
  /// to answer `405` with a correct `Allow` header.
  final Set<String> allowedMethods;
}

/// Everything the router resolved for the current request.
class HttpRoutePayload {
  const HttpRoutePayload({
    this.path = '',
    this.pathParameters = const {},
    this.extras = const {},
  });

  /// Registered path of the matched route, e.g. `/user/<id>`.
  final String path;

  /// Decoded `<parameter>` values captured from the request path.
  final Map<String, String> pathParameters;

  /// Values contributed by the controllers that ran before the handler.
  final Map<String, Object?> extras;

  /// Path parameter [name], or `null` when the route does not declare it.
  String? parameter(String name) => pathParameters[name];

  /// Extra [key] when it is present and of type [T], `null` otherwise.
  T? extra<T>(String key) {
    final value = extras[key];
    return value is T ? value : null;
  }
}

/// Thrown when a request body grows past the configured ceiling.
///
/// [LiteServer] turns this into a `413 Request Entity Too Large` response.
class HttpRequestTooLargeException implements Exception {
  const HttpRequestTooLargeException(this.limit);

  /// Maximum number of bytes that were allowed.
  final int limit;

  @override
  String toString() => 'Request body exceeds the $limit byte limit';
}

/// Thrown when a `multipart/*` body cannot be read.
class HttpMultipartException implements Exception {
  const HttpMultipartException(this.message);

  final String message;

  @override
  String toString() => 'HttpMultipartException: $message';
}
