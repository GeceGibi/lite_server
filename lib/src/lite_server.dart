import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    this.maxRequestSize = 10 * 1024 * 1024, // 10MB default
    this.requestTimeout = const Duration(seconds: 30),
  }) {
    generateRouteMap();
  }

  final List<HttpRoute> routes;
  final void Function(HttpRequest request)? onRouteNotFound;
  final void Function(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  )? onError;
  final int maxRequestSize;
  final Duration requestTimeout;

  ///
  List<HttpController> controllers = [];

  void listen(
    HttpServer server, {
    List<HttpController> controllers = const [],
    void Function(HttpRequest request, Object? error, StackTrace stackTrace)?
        onError,
  }) {
    this.controllers = controllers;
    server.asBroadcastStream().listen(
      requestHandler,
      cancelOnError: false,
      onError: (Object error, StackTrace stack) {
        // ignore: avoid_print
        print('Server error: $error');
      },
    );

    // ignore: avoid_print
    print(
      'LiteServer running on ${server.address.address}:${server.port}',
    );
  }

  ///
  final routeMap = <String, _HttpRouteMapper>{};

  (List<String>, List<HttpController>) _genRouteMap(
    List<HttpRoute> routes,
    List<HttpController> parentControllers,
    List<String> parentPaths,
  ) {
    for (final route in routes) {
      if (parentPaths.isNotEmpty && route.path.startsWith('/')) {
        throw Exception(
          'Sub routes path can\'t starts with "/", -> ${route.path}',
        );
      }

      if (parentPaths.isEmpty && !route.path.startsWith('/')) {
        throw Exception(
          'Main routes path must starts with "/", -> ${route.path}',
        );
      }

      final (paths, services) = _genRouteMap(
        route.routes ?? [],
        [...parentControllers, ...?route.controllers],
        [...parentPaths, route.path],
      );

      if (route.handler == null) {
        continue;
      }

      final normalizedPath = _HttpUtils.normalizePath(paths);
      routeMap[normalizedPath] = _HttpRouteMapper(route, services);
    }

    return (parentPaths, parentControllers);
  }

  void generateRouteMap() {
    routeMap.clear();
    _genRouteMap(routes, [], []);
  }

  (_HttpRouteMapper?, Map<String, String>) _findRoute(
    String requestPath,
    String method,
    List<HttpRoute>? searchRoutes,
  ) {
    // Optimize route matching with exact match first
    final exactMatch = routeMap[requestPath];
    if (exactMatch != null) {
      return (exactMatch, {});
    }

    // Then check dynamic routes
    for (final entry in routeMap.entries) {
      ///! Static file path
      if (entry.value.route is HttpStaticRoute) {
        if (requestPath.startsWith(entry.key)) {
          return (entry.value, {});
        }
      }

      ///! Dynamic paths
      else if (_HttpUtils.pathPattern.hasMatch(entry.key)) {
        final (isMatched, params) = _HttpUtils.routeHasMatch(
          requestPath,
          entry.key,
        );

        if (isMatched) {
          return (entry.value, params);
        }
      }
    }

    return (null, {});
  }

  (_HttpRouteMapper?, Map<String, String>) findRoute(HttpRequest request) {
    return _findRoute(
      request.uri.path,
      request.method,
      routes,
    );
  }

  Future<void> requestHandler(HttpRequest request) async {
    final errorListeners = <void Function(
      HttpRequest request,
      Object? error,
      StackTrace stackTrace,
    )>[];

    // Set request timeout
    final timeoutTimer = Timer(requestTimeout, () {
      try {
        request.response.statusCode = HttpStatus.requestTimeout;
        request.response.close();
      } catch (e) {
        // Response already closed
      }
    });

    try {
      // Check request size
      final contentLength = request.headers.contentLength;

      if (contentLength > maxRequestSize) {
        await request.response.status(
          HttpStatus.requestEntityTooLarge,
          message: 'Request too large',
        );
        return;
      }

      final extras = <String, Object?>{};

      /// Check Global services
      for (final controller in controllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
          timeoutTimer.cancel();
          return;
        }

        extras.addAll(behavior.extra);
      }

      /// Find route if request is not cut off from services
      final (routeMapper, pathParameters) = findRoute(request);

      ///! Check route is founded
      if (routeMapper == null) {
        if (onRouteNotFound != null) {
          onRouteNotFound!(request);
          timeoutTimer.cancel();
          return;
        }

        await request.response.notFound();
        timeoutTimer.cancel();
        return;
      }

      ///! check methods is allowed for route
      else if (!routeMapper.route.methods.contains(request.method)) {
        await request.response.methodNotAllowed();
        timeoutTimer.cancel();
        return;
      }

      for (final controller in routeMapper.controllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
          timeoutTimer.cancel();
          return;
        }

        extras.addAll(behavior.extra);
      }

      final payload = HttpRoutePayload(
        extras: extras,
        pathParameters: pathParameters,
      );

      await routeMapper.route.handler!(request, payload);
      timeoutTimer.cancel();
    } catch (error, stack) {
      timeoutTimer.cancel();

      /// Call services
      for (final callback in errorListeners) {
        try {
          callback(request, error, stack);
        } catch (e) {
          // ignore: avoid_print
          print('Error in error listener: $e');
        }
      }

      ///
      if (onError != null) {
        try {
          onError!(request, error, stack);
        } catch (e) {
          // ignore: avoid_print
          print('Error in global error handler: $e');
        }
        return;
      }

      await request.response.internalServerError();
    }
  }
}
