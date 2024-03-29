// ignore_for_file: constant_identifier_names

part of 'lite_server.dart';

/// Common requests handler before request accessed target route.
abstract class HttpService {
  // ignore: avoid_setters_without_getters
  set _onErrorStream(Stream<HttpRequestError> stream) {
    stream.listen((event) {
      onError(event.request, event.error, event.stackTrace);
    });
  }

  FutureOr<HttpServiceBehavior> onRequest(HttpRequest request);
  void onError(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  ) {}
}

/// ! --------------------------------------------------------------------------
class HttpServiceBehavior {
  /// Revoke request and cut it off
  /// Must handle request before call this
  HttpServiceBehavior.revoke()
      : next = false,
        extra = const {};

  /// Just move next
  HttpServiceBehavior.next({
    this.extra = const {},
  }) : next = true;

  final bool next;
  final Map<String, Object?> extra;
}

/// ! --------------------------------------------------------------------------
class LoggerService extends HttpService with LiteLogger {
  LoggerService({
    this.cleanLogsOnStart = false,
    this.logErrors = false,

    /// not recommend to use for now. Has a performance issues.
    this.logRequests = false,
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
  FutureOr<HttpServiceBehavior> onRequest(HttpRequest request) {
    if (!printLogs && !logRequests) {
      return HttpServiceBehavior.next();
    }

    final now = DateTime.now();
    final clock = Stopwatch()..start();

    request.response.done.then((value) {
      clock.stop();

      final line = [
        now.toIso8601String(),
        clock.elapsed.toString(),
        request.method,
        if (request.connectionInfo != null)
          [
            request.connectionInfo?.remoteAddress.address,
            request.connectionInfo?.remotePort,
          ].join(':'),
        request.response.statusCode,
        request.response.headers.contentType,
        request.uri,
      ];

      if (printLogs) {
        // ignore: avoid_print
        print(line.join(' | '));
      }

      if (!logRequests) {
        return HttpServiceBehavior.next();
      }

      log('${line.join(' | ')}\n', name: 'request_');
    });

    return HttpServiceBehavior.next();
  }

  @override
  void onError(
    HttpRequest request,
    Object? error,
    StackTrace stackTrace,
  ) {
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
    this.allowedOrigins = const {'*'},
    this.allowedHeaders = headers,
    this.allowedMethods = methods,
    this.maxAge = const Duration(hours: 24),
    this.allowCredentials = true,
    this.exposeHeaders = '',
  });

  final Set<String> allowedOrigins;
  final Set<String> allowedHeaders;
  final Set<String> allowedMethods;
  final Duration maxAge;
  final bool allowCredentials;
  final String exposeHeaders;

  static const headers = {
    'access-control-allow-origin',
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
  };

  static const methods = {
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
  };

  @override
  FutureOr<HttpServiceBehavior> onRequest(HttpRequest request) {
    if (!allowedMethods.contains(request.method)) {
      request.response.methodNotAllowed();
      return HttpServiceBehavior.revoke();
    }

    final corsHeaders = {
      'Access-Control-Expose-Headers': [exposeHeaders],
      'Access-Control-Allow-Credentials': ['$allowCredentials'],
      'Access-Control-Allow-Origin': allowedOrigins.toList(),
      'Access-Control-Max-Age': [maxAge.inSeconds.toString()],
      'Access-Control-Allow-Headers': [allowedHeaders.join(',')],
      'Access-Control-Allow-Methods': [allowedMethods.join(',')],
    };

    for (final header in corsHeaders.entries) {
      request.response.headers.set(header.key, header.value);
    }

    if (request.method == 'OPTIONS') {
      request.response.ok(null);
      return HttpServiceBehavior.revoke();
    }

    return HttpServiceBehavior.next();
  }
}
