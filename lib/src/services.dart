// ignore_for_file: constant_identifier_names

part of 'lite_server.dart';

abstract class HttpService {
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
  HttpServiceBehavior.revoke()
      : moveOn = false,
        extra = const {};

  HttpServiceBehavior.next({
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

    /// not recommend to use for now. Has a performance issues.
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
            request.connectionInfo!.remoteAddress.address,
            request.connectionInfo!.remotePort
          ].join(':'),
        request.response.statusCode,
        request.response.headers.contentType,
        request.uri,
      ];

      if (printLogs) {
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
  });

  final Set<String> allowedOrigins;
  final Set<String> allowedHeaders;
  final Set<String> allowedMethods;

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
    final corsHeaders = {
      'Access-Control-Expose-Headers': [''],
      'Access-Control-Allow-Credentials': ['true'],
      'Access-Control-Allow-Origin': allowedOrigins.toList(),
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
      return HttpServiceBehavior.revoke();
    }

    return HttpServiceBehavior.next();
  }
}
