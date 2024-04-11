// ignore_for_file: constant_identifier_names

part of 'lite_server.dart';

/// Common requests handler before request accessed target route.
abstract class HttpController {
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request);
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {}
}

/// ! --------------------------------------------------------------------------
class HttpControllerBehavior {
  /// Revoke request and cut it off
  /// Must handle request before call this
  HttpControllerBehavior.revoke()
      : next = false,
        extra = const {};

  /// Just move next
  HttpControllerBehavior.next({
    this.extra = const {},
  }) : next = true;

  final bool next;
  final Map<String, Object?> extra;
}

/// ! --------------------------------------------------------------------------
///
///

class _Logger {
  _Logger._() {
    init();
  }

  static final instance = _Logger._();

  Directory _directory = Directory('./logs');
  Directory get directory => _directory;
  void setDirectory(String path) {
    _directory = Directory(path);
  }

  RandomAccessFile? fileRequests;
  RandomAccessFile? fileErrors;

  void init() {
    final requestsLogFile = File('${directory.path}/requests.log')
      ..createSync(recursive: true);

    final errorsLogFile = File('${directory.path}/errors.log')
      ..create(recursive: true);

    fileRequests = requestsLogFile.openSync(mode: FileMode.append);
    fileErrors = errorsLogFile.openSync(mode: FileMode.append);
  }

  String _clean(String line) {
    final cleaned = line
        .replaceAll(RegExp('\n+'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.endsWith(',')) {
      return cleaned.substring(0, cleaned.length - 1);
    }

    return cleaned;
  }

  void cleanFiles() {
    fileRequests?.truncate(0);
    fileErrors?.truncate(0);
  }

  void appendError(String line) {
    fileErrors
      ?..writeStringSync('${_clean(line)}\n')
      ..flushSync();
  }

  void appendRequest(String line) {
    fileRequests
      ?..writeStringSync('${_clean(line)}\n')
      ..flushSync();
  }
}

class LoggerController extends HttpController {
  LoggerController({
    this.logErrors = true,
    this.logRequests = true,
    this.printLogs = true,
    this.logDirectory = './logs',
  }) {
    _Logger.instance
      ..setDirectory(logDirectory)
      ..cleanFiles();
  }

  final bool logErrors;
  final bool printLogs;
  final bool logRequests;
  final String logDirectory;

  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    if (!printLogs && !logRequests) {
      return HttpControllerBehavior.next();
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
            request.connectionInfo!.remotePort,
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
        return HttpControllerBehavior.next();
      }

      _Logger.instance.appendRequest(line.join(' | '));
    });

    return HttpControllerBehavior.next();
  }

  @override
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {
    if (!logErrors) {
      return;
    }

    final now = DateTime.now();

    final line = [
      now.toIso8601String(),
      if (request.connectionInfo != null)
        [
          request.connectionInfo!.remoteAddress.address,
          request.connectionInfo!.remotePort,
        ].join(':'),
      '${request.uri}',
      error,
      stackTrace,
    ];

    _Logger.instance.appendError(line.join(' | '));
  }
}

/// ! --------------------------------------------------------------------------

class CorsOriginController extends HttpController {
  CorsOriginController({
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
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    if (!allowedMethods.contains(request.method)) {
      request.response.methodNotAllowed();
      return HttpControllerBehavior.revoke();
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
      return HttpControllerBehavior.revoke();
    }

    return HttpControllerBehavior.next();
  }
}
