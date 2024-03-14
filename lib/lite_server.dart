library lite_server;

import 'dart:async';
import 'dart:io';

import 'package:mime/mime.dart';

part 'router.dart';
part 'services.dart';
part 'utils.dart';
part 'logger.dart';

class _HttpRouteMapper {
  const _HttpRouteMapper(this.route, this.services);
  final HttpRoute route;
  final List<HttpService> services;
}

class LiteServer with LiteLogger {
  LiteServer.attach(
    this.server, {
    this.routes = const [],
    this.services = const [],
    this.errorHandler,
    this.onRouteNotFound = _defaultRouteNotFound,
    this.logRequests = false,
    this.logErrors = false,
    this.cleanLogsOnStart = false,
  }) {
    if (cleanLogsOnStart) {
      clearLogs();
    }

    generateRouteMap();

    server.asBroadcastStream().listen(requestHandler);
    print('LiteServer running on(${server.address.address}:${server.port})');
  }

  final bool logRequests;
  final bool logErrors;
  final bool cleanLogsOnStart;

  final HttpServer server;
  final List<HttpService> services;
  final List<HttpRoute> routes;

  final void Function(HttpRequest request) onRouteNotFound;
  final void Function(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  )? errorHandler;

  static void _defaultRouteNotFound(HttpRequest request) {
    request.response.statusCode = HttpStatus.notFound;
    request.response.close();
  }

  final routeMap = <String, _HttpRouteMapper>{};

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

      if (route.handler == null) {
        continue;
      }

      final (paths, services) = _genRouteMap(
        route.routes ?? [],
        [...parentServices, ...?route.services],
        [...parentPaths, route.path],
      );

      routeMap[paths.join('/')] = _HttpRouteMapper(route, services);
    }

    return (parentPaths, parentServices);
  }

  void generateRouteMap() {
    routeMap.clear();
    _genRouteMap(routes, [], []);
    print(routeMap.keys.join('\n'));
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

  void requestHandler(HttpRequest request) async {
    if (logRequests) {
      log(
        [
          '## URI ##',
          '${request.uri}\n',
          '## HEADERS ##',
          '${request.headers}',
          '## CONNECTION INFO ##',
          'IP: ${request.connectionInfo?.remoteAddress.address}',
          'PORT: ${request.connectionInfo?.remotePort}\n',
        ].join('\n'),
        prefix: 'request_',
      );
    }

    try {
      final (routeMapper, pathParameters) = findRoute(request);

      final extras = <String, Object?>{};

      /// Check Global services
      for (final service in services) {
        final (passedRequest, extra) = await service.handleRequest(request);

        if (passedRequest == null) {
          return;
        }

        if (extra != null) {
          extras.addAll(extra);
        }
      }

      if (routeMapper == null) {
        onRouteNotFound(request);
      } else {
        for (final service in routeMapper.services) {
          final (passedRequest, extra) = await service.handleRequest(request);

          if (passedRequest == null) {
            return;
          }

          if (extra != null) {
            extras.addAll(extra);
          }
        }

        routeMapper.route.handler?.call(
          request,
          HttpRoutePayload(
            extras: extras,
            pathParameters: pathParameters,
          ),
        );
      }
    } catch (error, stack) {
      errorHandler?.call(request, error, stack);

      if (logErrors) {
        log(
          [
            '## URI ##',
            '${request.uri}\n',

            '## HEADERS ##',
            '${request.headers}',

            '## CONNECTION INFO ##',
            'IP: ${request.connectionInfo?.remoteAddress.address}',
            'PORT: ${request.connectionInfo?.remotePort}\n',

            ///
            error,
            stack,
          ].join('\n'),
          prefix: 'error_',
        );
      }
    }
  }
}
