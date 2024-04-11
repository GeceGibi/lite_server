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
    this.controllers = const [],
    this.onError,
    this.onRouteNotFound,
  }) {
    generateRouteMap();
  }

  final List<HttpController> controllers;
  final List<HttpRoute> routes;

  /// local vars
  final routeMap = <String, _HttpRouteMapper>{};

  final void Function(HttpRequest request)? onRouteNotFound;
  final void Function(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  )? onError;

  void listen(HttpServer server) {
    server.asBroadcastStream().listen(requestHandler, cancelOnError: false);

    // ignore: avoid_print
    print('LiteServer running on(${server.address.address}:${server.port})');
  }

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

      ///! Not dynamic paths
      else if (entry.key == requestPath) {
        return (entry.value, {});
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

    try {
      final extras = <String, Object?>{};

      /// Check Global services
      for (final controller in controllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
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
          return;
        }

        await request.response.notFound();
        return;
      }

      ///! check methods is allowed for route
      else if (!routeMapper.route.methods.contains(request.method)) {
        await request.response.methodNotAllowed();
        return;
      }

      for (final controller in routeMapper.controllers) {
        errorListeners.add(controller.onError);
        final behavior = await controller.onRequest(request);

        if (!behavior.next) {
          return;
        }

        extras.addAll(behavior.extra);
      }

      final payload = HttpRoutePayload(
        extras: extras,
        pathParameters: pathParameters,
      );

      await routeMapper.route.handler!(request, payload);
    } catch (error, stack) {
      /// Call services
      for (final callback in errorListeners) {
        callback(request, error, stack);
      }

      ///
      if (onError != null) {
        onError!(request, error, stack);
        return;
      }

      await request.response.internalServerError();
    }
  }
}
