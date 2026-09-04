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
  const HttpControllerBehavior.revoke()
      : next = false,
        extra = const {};

  /// Just move next
  const HttpControllerBehavior.next({
    this.extra = const {},
  }) : next = true;

  final bool next;
  final Map<String, Object?> extra;
}

/// ! --------------------------------------------------------------------------
///
///

/// Appends log lines to date stamped files under [directory].
///
/// Files are opened lazily on the first write and reopened when the date
/// changes, so a long running server keeps writing into the file for the
/// current day instead of the one it started on.
class LiteServerLogger {
  LiteServerLogger({required String path}) : directory = Directory(path);

  final Directory directory;

  RandomAccessFile? _requests;
  RandomAccessFile? _errors;
  String? _openedFor;

  /// Name of the log file for today, e.g. `04-09-2026.log`.
  String get fileName {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$day-$month-$year.log';
  }

  File get logFileRequests => File('${directory.path}/requests/$fileName');

  File get logFileErrors => File('${directory.path}/errors/$fileName');

  /// Opens today's files, rotating away from yesterday's if needed.
  bool _openFiles() {
    final today = fileName;

    if (_openedFor == today && _requests != null && _errors != null) {
      return true;
    }

    close();

    try {
      final requests = logFileRequests;
      final errors = logFileErrors;

      if (!requests.existsSync()) {
        requests.createSync(recursive: true);
      }

      if (!errors.existsSync()) {
        errors.createSync(recursive: true);
      }

      _requests = requests.openSync(mode: FileMode.append);
      _errors = errors.openSync(mode: FileMode.append);
      _openedFor = today;

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error creating log files: $e');
      return false;
    }
  }

  /// Releases the open file handles. Safe to call more than once.
  void close() {
    try {
      _requests?.closeSync();
      _errors?.closeSync();
    } catch (e) {
      // ignore: avoid_print
      print('Error closing log files: $e');
    }

    _requests = null;
    _errors = null;
    _openedFor = null;
  }

  void cleanLogs() {
    close();

    try {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error cleaning logs: $e');
    }
  }

  /// Collapses a log line onto a single line so one entry stays one row.
  String _clean(String line) {
    final cleaned =
        line.replaceAll('\n', ', ').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.endsWith(',')) {
      return cleaned.substring(0, cleaned.length - 1);
    }

    return cleaned;
  }

  void appendErrorLine(String line) {
    _append(line, isError: true);
  }

  void appendRequestLine(String line) {
    _append(line, isError: false);
  }

  void _append(String line, {required bool isError}) {
    if (!_openFiles()) {
      return;
    }

    try {
      (isError ? _errors : _requests)
        ?..writeStringSync('${_clean(line)}\n')
        ..flushSync();
    } catch (e) {
      // ignore: avoid_print
      print('Error writing to log: $e');
    }
  }
}

/// Which log lines [LoggerController] persists to disk.
enum LogLevel {
  all,
  errors,
  requests,
  none;
}

/// Logs one line per request and per unhandled error.
///
/// [level] controls what is written to disk and [printLogs] controls the
/// console output, so file logging can be turned off without going silent and
/// the other way around. No log directory is created until something is
/// actually written.
class LoggerController extends HttpController {
  LoggerController({
    this.level = LogLevel.none,
    this.path = './logs',
    this.printLogs = true,
  }) : logger = LiteServerLogger(path: path);

  final LiteServerLogger logger;
  final LogLevel level;
  final String path;

  /// Mirror every line to stdout.
  final bool printLogs;

  bool get _writesRequests =>
      level == LogLevel.requests || level == LogLevel.all;

  bool get _writesErrors => level == LogLevel.errors || level == LogLevel.all;

  String get time => DateTime.now().toIso8601String();

  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    if (!printLogs && !_writesRequests) {
      return const HttpControllerBehavior.next();
    }

    final clock = Stopwatch()..start();
    final method = request.method;
    final uri = request.uri;
    final userAgent =
        request.headers.value(HttpHeaders.userAgentHeader) ?? 'Unknown';

    unawaited(
      request.response.done.then((_) {
        clock.stop();

        final line = [
          time,
          clock.elapsed.toString(),
          method,
          request.response.statusCode,
          uri,
          userAgent,
        ].join(' | ');

        if (printLogs) {
          // ignore: avoid_print
          print(line);
        }

        if (_writesRequests) {
          logger.appendRequestLine(line);
        }
      }).catchError((Object error) {
        if (printLogs) {
          // ignore: avoid_print
          print('Error in request logging: $error');
        }
      }),
    );

    return const HttpControllerBehavior.next();
  }

  @override
  void onError(HttpRequest request, Object? error, StackTrace stackTrace) {
    if (!printLogs && !_writesErrors) {
      return;
    }

    final line = [time, '${request.uri}', error, stackTrace].join(' | ');

    if (printLogs) {
      // ignore: avoid_print
      print(line);
    }

    if (_writesErrors) {
      logger.appendErrorLine(line);
    }
  }
}

/// ! --------------------------------------------------------------------------

/// Adds CORS headers and answers preflight requests.
///
/// `Access-Control-Allow-Origin` carries a single value: the request's own
/// origin when it is allowed. Sending the whole allow list at once, or sending
/// `*` next to `Access-Control-Allow-Credentials: true`, makes browsers reject
/// the response outright.
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
    final response = request.response;
    final origin = request.headers.value('origin');
    final allowsAnyOrigin = allowedOrigins.contains('*');
    final isPreflight = request.method == 'OPTIONS';

    if (!allowedMethods.contains(request.method)) {
      response.headers.set(
        HttpHeaders.allowHeader,
        allowedMethods.join(', '),
      );

      response.methodNotAllowed().ignore();
      return const HttpControllerBehavior.revoke();
    }

    final isAllowedOrigin =
        origin != null && (allowsAnyOrigin || allowedOrigins.contains(origin));

    if (isAllowedOrigin) {
      if (allowsAnyOrigin && !allowCredentials) {
        response.headers.set('Access-Control-Allow-Origin', '*');
      } else {
        /// The response now varies per origin, so caches must key on it.
        response.headers
          ..set('Access-Control-Allow-Origin', origin)
          ..add(HttpHeaders.varyHeader, 'Origin');
      }

      if (allowCredentials) {
        response.headers.set('Access-Control-Allow-Credentials', 'true');
      }

      if (exposeHeaders.isNotEmpty) {
        response.headers.set('Access-Control-Expose-Headers', exposeHeaders);
      }
    }

    if (!isPreflight) {
      return const HttpControllerBehavior.next();
    }

    response.headers
      ..set('Access-Control-Allow-Headers', allowedHeaders.join(','))
      ..set('Access-Control-Allow-Methods', allowedMethods.join(','))
      ..set('Access-Control-Max-Age', maxAge.inSeconds.toString());

    response.statusCode = HttpStatus.noContent;
    response.close().ignore();

    return const HttpControllerBehavior.revoke();
  }
}
