// ignore_for_file: constant_identifier_names

part of 'lite_server.dart';

abstract class HttpService {
  set _onErrorStream(Stream<HttpRequestError> stream) {
    stream.listen((event) {
      onError(event.request, event.error, event.stackTrace);
    });
  }

  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request);
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {}
}

/// ! --------------------------------------------------------------------------
class HttpServiceBehavior {
  HttpServiceBehavior.cutOff()
      : moveOn = false,
        extra = const {};

  HttpServiceBehavior.moveOn({
    this.extra = const {},
  }) : moveOn = true;

  final bool moveOn;
  final Map<String, Object?> extra;
}

/// ! --------------------------------------------------------------------------
class LoggerService extends HttpService with LiteLogger {
  LoggerService({
    this.cleanLogsOnStart = true,
    this.logErrors = true,
    this.logRequests = true,
    this.printLogs = true,
  }) {
    if (cleanLogsOnStart) {
      clearLogs();
    }
  }

  final bool printLogs;
  final bool logRequests;
  final bool logErrors;
  final bool cleanLogsOnStart;

  @override
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
    if (printLogs) {
      final now = DateTime.now();
      print('$now: ${request.method} | ${request.uri}');
    }

    if (!logRequests) {
      return HttpServiceBehavior.moveOn();
    }

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

    return HttpServiceBehavior.moveOn();
  }

  @override
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {
    if (!logErrors) {
      return;
    }

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
        stackTrace,
      ].join('\n'),
      prefix: 'error_',
    );
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
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
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
      return HttpServiceBehavior.cutOff();
    }

    return HttpServiceBehavior.moveOn();
  }
}
