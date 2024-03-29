import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

part 'router.dart';
part 'services.dart';
part 'utils.dart';
part 'logger.dart';
part 'extensions.dart';
part 'models.dart';

class LiteServer {
  LiteServer({
    this.routes = const [],
    this.services = const [],
    this.onError,
    this.onRouteNotFound,
  }) {
    generateRouteMap();
  }

  final List<HttpService> services;
  final List<HttpRoute> routes;

  /// local vars
  final routeMap = <String, _HttpRouteMapper>{};

  ///
  final _onErrorStreamController =
      StreamController<HttpRequestError>.broadcast();

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

  (List<String>, List<HttpService>) _genRouteMap(
    List<HttpRoute> routes,
    List<HttpService> parentServices,
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
        [...parentServices, ...?route.services],
        [...parentPaths, route.path],
      );

      if (route.handler == null) {
        continue;
      }

      final normalizedPath = HttpUtils.normalizePath(paths);
      routeMap[normalizedPath] = _HttpRouteMapper(route, services);
    }

    return (parentPaths, parentServices);
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
      else if (HttpUtils.pathPattern.hasMatch(entry.key)) {
        final (isMatched, params) = HttpUtils.routeHasMatch(
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
    try {
      final extras = <String, Object?>{};

      /// Check Global services
      for (final service in services) {
        service._onErrorStream = _onErrorStreamController.stream;
        final behavior = await service.onRequest(request);

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

      for (final service in routeMapper.services) {
        service._onErrorStream = _onErrorStreamController.stream;
        final behavior = await service.onRequest(request);

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
      _onErrorStreamController.add(HttpRequestError(request, error, stack));

      ///
      if (onError != null) {
        onError!(request, error, stack);
        return;
      }

      await request.response.internalServerError();
    }
  }
}
