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

class CorsOriginService extends HttpService {
  CorsOriginService({
    this.allowedOrigins = const ['*'],
    this.allowedHeaders = defaultAllowedHeaders,
    this.allowedMethods = defaultAllowedMethods,
  });

  final List<String> allowedOrigins;
  final List<String> allowedHeaders;
  final List<String> allowedMethods;

  static const defaultAllowedHeaders = [
    'access-control-allow-origin',
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
  ];

  static const defaultAllowedMethods = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT'
  ];

  @override
  FutureOr<(HttpRequest?, Map<String, Object?>?)> handleRequest(
    HttpRequest request,
  ) {
    final corsHeaders = {
      'Access-Control-Expose-Headers': [''],
      'Access-Control-Allow-Credentials': ['true'],
      'Access-Control-Allow-Origin': allowedOrigins,
      'Access-Control-Max-Age': [Duration(hours: 24).inSeconds.toString()],
      'Access-Control-Allow-Headers': [allowedHeaders.join(',')],
      'Access-Control-Allow-Methods': [allowedMethods.join(',')],
    };

    for (final header in corsHeaders.entries) {
      request.response.headers.set(header.key, header.value);
    }

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      request.response.close();
      return (null, null);
    }

    return (request, null);
  }
}
