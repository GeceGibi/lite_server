import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

part 'router.dart';
part 'controller.dart';
part 'utils.dart';
part 'extensions.dart';
part 'models.dart';

class LiteServer {
  LiteServer({
    this.routes = const [],
    this.onRouteNotFound,
    this.onError,
    this.maxRequestSize = defaultMaxRequestSize,
    this.requestTimeout = const Duration(seconds: 30),
  }) {
    generateRouteMap();
  }

  /// Default ceiling for request bodies, 10MB.
  static const int defaultMaxRequestSize = 10 * 1024 * 1024;

  final List<HttpRoute> routes;
  final FutureOr<void> Function(HttpRequest request)? onRouteNotFound;
  final void Function(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  )? onError;

  /// Maximum number of body bytes accepted per request. Enforced both from
  /// `Content-Length` and while the body is being read, so a chunked upload
  /// without a declared length cannot slip past it.
  final int maxRequestSize;

  /// How long a request may take before it is answered with `408`.
  final Duration requestTimeout;

  /// Controllers passed to the most recent [listen] call.
  List<HttpController> controllers = [];

  /// Absolute route path to every route registered for that path.
  ///
  /// A path may hold more than one route as long as their methods do not
  /// overlap, which is what makes `GET /user/<id>` and `POST /user/<id>`
  /// coexist.
  final routeMap = <String, List<_HttpRouteMapper>>{};

  /// Paths without placeholders, matched with a map lookup.
  final _literalRoutes = <String, List<_HttpRouteMapper>>{};

  /// Paths with `<parameter>` placeholders, matched against their pattern.
  final _dynamicRoutes = <_HttpRouteMapper>[];

  /// [HttpStaticRoute] mount points, matched by path prefix.
  final _staticFileRoutes = <_HttpRouteMapper>[];

  /// Starts handling requests from [server].
  ///
  /// The returned subscription lets the caller stop serving without closing
  /// [server] itself.
  StreamSubscription<HttpRequest> listen(
    HttpServer server, {
    List<HttpController> controllers = const [],
    void Function(HttpRequest request, Object? error, StackTrace stackTrace)?
        onError,
    bool logStartup = true,
  }) {
    this.controllers = controllers;

    final subscription = server.listen(
      (request) => _handle(request, controllers, onError).ignore(),
      cancelOnError: false,
      onError: (Object error, StackTrace stackTrace) {
        // ignore: avoid_print
        print('LiteServer socket error: $error');
      },
    );

    if (logStartup) {
      // ignore: avoid_print
      print('LiteServer running on ${server.address.address}:${server.port}');
    }

    return subscription;
  }

  /// Rebuilds the route table from [routes].
  ///
  /// Throws an [ArgumentError] when a path is nested incorrectly or when two
  /// routes claim the same path and method.
  void generateRouteMap() {
    routeMap.clear();
    _literalRoutes.clear();
    _dynamicRoutes.clear();
    _staticFileRoutes.clear();

    _collectRoutes(routes, const [], const []);

    // Longest mount first so `/images/thumbs` wins over `/images`.
    _staticFileRoutes.sort((a, b) => b.path.length.compareTo(a.path.length));
  }

  void _collectRoutes(
    List<HttpRoute> routes,
    List<HttpController> parentControllers,
    List<String> parentPaths,
  ) {
    for (final route in routes) {
      if (parentPaths.isNotEmpty && route.path.startsWith('/')) {
        throw ArgumentError.value(
          route.path,
          'path',
          'sub route paths must not start with "/"',
        );
      }

      if (parentPaths.isEmpty && !route.path.startsWith('/')) {
        throw ArgumentError.value(
          route.path,
          'path',
          'top level route paths must start with "/"',
        );
      }

      final paths = [...parentPaths, route.path];
      final controllers = [...parentControllers, ...?route.controllers];

      _collectRoutes(route.routes ?? const [], controllers, paths);

      /// A route without a handler only groups its children.
      if (route.handler == null) {
        continue;
      }

      _register(
        _HttpRouteMapper(route, controllers, _HttpUtils.normalizePath(paths)),
      );
    }
  }

  void _register(_HttpRouteMapper mapper) {
    final siblings = routeMap.putIfAbsent(mapper.path, () => []);

    for (final sibling in siblings) {
      final overlap = sibling.methods.intersection(mapper.methods);

      if (overlap.isNotEmpty) {
        throw ArgumentError.value(
          mapper.path,
          'routes',
          'duplicate route for ${overlap.join(', ')}',
        );
      }
    }

    siblings.add(mapper);

    if (mapper.isStaticFileRoute) {
      _staticFileRoutes.add(mapper);
    } else if (mapper.isDynamic) {
      _dynamicRoutes.add(mapper);
    } else {
      (_literalRoutes[mapper.path] ??= []).add(mapper);
    }
  }

  /// Resolves [request] to the route that should handle it.
  (_HttpRouteMapper?, Map<String, String>) findRoute(HttpRequest request) {
    final resolution = _resolve(request.uri.path, request.method);
    return (resolution.mapper, resolution.pathParameters);
  }

  /// Matches literal paths first, then paths with placeholders, then static
  /// file mounts, so a concrete route always wins over a broader one.
  _RouteResolution _resolve(String requestPath, String method) {
    final path = _HttpUtils.normalizeRequestPath(requestPath);
    final allowedMethods = <String>{};

    for (final mapper in _literalRoutes[path] ?? const <_HttpRouteMapper>[]) {
      if (mapper.methods.contains(method)) {
        return _RouteResolution(mapper: mapper);
      }

      allowedMethods.addAll(mapper.methods);
    }

    for (final mapper in _dynamicRoutes) {
      final params = _HttpUtils.matchParams(
        mapper.pattern!,
        mapper.parameterNames,
        path,
      );

      if (params == null) {
        continue;
      }

      if (mapper.methods.contains(method)) {
        return _RouteResolution(mapper: mapper, pathParameters: params);
      }

      allowedMethods.addAll(mapper.methods);
    }

    for (final mapper in _staticFileRoutes) {
      if (!_isUnderMount(path, mapper.path)) {
        continue;
      }

      if (mapper.methods.contains(method)) {
        return _RouteResolution(mapper: mapper);
      }

      allowedMethods.addAll(mapper.methods);
    }

    return _RouteResolution(allowedMethods: allowedMethods);
  }

  static bool _isUnderMount(String path, String mountPath) {
    if (mountPath == '/') {
      return true;
    }

    return path == mountPath || path.startsWith('$mountPath/');
  }

  Future<void> requestHandler(HttpRequest request) {
    return _handle(request, controllers);
  }

  Future<void> _handle(
    HttpRequest request,
    List<HttpController> globalControllers, [
    void Function(HttpRequest request, Object? error, StackTrace stackTrace)?
        listenOnError,
  ]) async {
    final errorListeners = <void Function(
      HttpRequest request,
      Object? error,
      StackTrace stackTrace,
    )>[];

    var timedOut = false;

    final timeoutTimer = Timer(requestTimeout, () {
      timedOut = true;

      try {
        request.response.statusCode = HttpStatus.requestTimeout;
        request.response.close().ignore();
      } catch (_) {
        // The response was already committed, nothing left to send.
      }
    });

    /// Published so the body helpers can enforce the same ceiling while they
    /// read, without every handler having to pass it around.
    _maxBodySizes[request] = maxRequestSize;

    try {
      if (request.headers.contentLength > maxRequestSize) {
        await request.response.status(
          HttpStatus.requestEntityTooLarge,
          message: 'Request too large',
        );
        return;
      }

      final extras = <String, Object?>{};

      /// Global controllers run for every request, matched or not.
      for (final controller in globalControllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
          return;
        }

        extras.addAll(behavior.extra);
      }

      final resolution = _resolve(request.uri.path, request.method);
      final mapper = resolution.mapper;

      if (mapper == null) {
        ///! The path exists but not for this method.
        if (resolution.allowedMethods.isNotEmpty) {
          request.response.headers.set(
            HttpHeaders.allowHeader,
            resolution.allowedMethods.join(', '),
          );

          await request.response.methodNotAllowed();
          return;
        }

        if (onRouteNotFound != null) {
          await onRouteNotFound!(request);
          return;
        }

        await request.response.notFound();
        return;
      }

      for (final controller in mapper.controllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
          return;
        }

        extras.addAll(behavior.extra);
      }

      await mapper.route.handler!(
        request,
        HttpRoutePayload(
          path: mapper.path,
          extras: extras,
          pathParameters: resolution.pathParameters,
        ),
      );
    } catch (error, stackTrace) {
      for (final callback in errorListeners) {
        try {
          callback(request, error, stackTrace);
        } catch (e) {
          // ignore: avoid_print
          print('Error in error listener: $e');
        }
      }

      final handler = onError ?? listenOnError;

      if (handler != null) {
        try {
          handler(request, error, stackTrace);
        } catch (e) {
          // ignore: avoid_print
          print('Error in global error handler: $e');
        }
        return;
      }

      /// The timeout already answered this request.
      if (timedOut) {
        return;
      }

      if (error is HttpRequestTooLargeException) {
        await _respondQuietly(
          request,
          HttpStatus.requestEntityTooLarge,
          'Request too large',
        );
        return;
      }

      await _respondQuietly(request, HttpStatus.internalServerError, null);
    } finally {
      timeoutTimer.cancel();
      _maxBodySizes[request] = null;
    }
  }

  /// Sends [statusCode], swallowing the failure when the response is already
  /// committed or the client is gone. Without this the error path itself would
  /// throw and surface as an unhandled asynchronous error.
  static Future<void> _respondQuietly(
    HttpRequest request,
    int statusCode,
    String? message,
  ) async {
    try {
      await request.response.status(statusCode, message: message);
    } catch (_) {
      // Nothing can be delivered anymore.
    }
  }
}
