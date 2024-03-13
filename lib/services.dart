// ignore_for_file: constant_identifier_names

part of 'lite_server.dart';

abstract class HttpService {
  FutureOr<(HttpRequest? request, Map<String, Object?>? extra)> handleRequest(
      HttpRequest request);
}

/// ! --------------------------------------------------------------------------
class LoggerService extends HttpService {
  @override
  FutureOr<(HttpRequest?, Map<String, Object?>?)> handleRequest(
    HttpRequest request,
  ) {
    final now = DateTime.now();
    print('$now: ${request.method} | ${request.uri}');
    return (request, null);
  }
}

/// ! --------------------------------------------------------------------------

const _allowedMethods = ['DELETE', 'GET', 'OPTIONS', 'PATCH', 'POST', 'PUT'];
const _allowedHeaders = [
  'access-control-allow-origin',
  'accept',
  'accept-encoding',
  'authorization',
  'content-type',
  'dnt',
  'origin',
  'user-agent',
];

class CorsOriginService extends HttpService {
  CorsOriginService({
    this.allowedOrigins = const ['*'],
    this.allowedHeaders = _allowedHeaders,
    this.allowedMethods = _allowedMethods,
  });

  final List<String> allowedOrigins;
  final List<String> allowedHeaders;
  final List<String> allowedMethods;

  @override
  FutureOr<(HttpRequest?, Map<String, Object?>?)> handleRequest(
    HttpRequest request,
  ) {
    if (request.method == 'OPTIONS') {
      request.response.headers.set('Access-Control-Expose-Headers', '');
      request.response.headers.set('Access-Control-Allow-Credentials', 'true');

      request.response.headers.set(
        'Access-Control-Allow-Origin',
        allowedOrigins,
      );

      request.response.headers.set(
        'Access-Control-Max-Age',
        Duration(hours: 24).inSeconds.toString(),
      );

      request.response.headers.set(
        'Access-Control-Allow-Headers',
        allowedHeaders.join(','),
      );

      request.response.headers.set(
        'Access-Control-Allow-Methods',
        allowedMethods.join(','),
      );

      request.response.close();
      return (null, null);
    }

    return (request, null);
  }
}
