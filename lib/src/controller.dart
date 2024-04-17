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

class LiteServerLogger {
  LiteServerLogger._() {
    _init();
  }

  static final instance = LiteServerLogger._();

  Directory _directory = Directory('./logs');
  Directory get directory => _directory;
  void setDirectory(String? path) {
    if (path == null) {
      return;
    }

    _directory = Directory(path);
  }

  RandomAccessFile? fileRequests;
  RandomAccessFile? fileErrors;

  String get fileName {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$day-$month-$year.log';
  }

  File get requestsLogFile => File('${directory.path}/requests/$fileName');
  File get errorsLogFile => File('${directory.path}/errors/$fileName');

  void _checkFilesAndCreateIfNeeded() {
    if (!requestsLogFile.existsSync()) {
      requestsLogFile.createSync(recursive: true);
    }

    if (!errorsLogFile.existsSync()) {
      errorsLogFile.createSync(recursive: true);
    }

    fileRequests = requestsLogFile.openSync(mode: FileMode.append);
    fileErrors = errorsLogFile.openSync(mode: FileMode.append);
  }

  Future<void> _init() async {
    while (true) {
      _checkFilesAndCreateIfNeeded();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  void cleanLogs() {
    directory.deleteSync(recursive: true);
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

  void appendErrorLine(String line) {
    fileErrors
      ?..writeStringSync('${_clean(line)}\n')
      ..flushSync();
  }

  void appendRequestLine(String line) {
    fileRequests
      ?..writeStringSync('${_clean(line)}\n')
      ..flushSync();
  }
}

enum LogLevel {
  all,
  errors,
  requests,
  none;
}

class LoggerController extends HttpController {
  LoggerController({this.level = LogLevel.none, this.directory}) {
    LiteServerLogger.instance.setDirectory(directory);
  }

  final LogLevel level;
  final String? directory;

  String get time => DateTime.now().toIso8601String();

  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    final clock = Stopwatch()..start();

    request.response.done.then((value) {
      clock.stop();

      final line = [
        time,
        clock.elapsed.toString(),
        request.method,
        request.response.statusCode,
        request.uri,
      ].join(' | ');

      // ignore: avoid_print
      print(line);

      if (level case LogLevel.requests || LogLevel.all) {
        LiteServerLogger.instance.appendRequestLine(line);
      }
    });

    return HttpControllerBehavior.next();
  }

  @override
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {
    final line = [time, '${request.uri}', error, stackTrace].join(' | ');

    // ignore: avoid_print
    print(line);

    if (level case LogLevel.errors || LogLevel.all) {
      LiteServerLogger.instance.appendErrorLine(line);
    }
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
      request.response.statusCode = 204;
      request.response.close();
      return HttpControllerBehavior.revoke();
    }

    return HttpControllerBehavior.next();
  }
}
