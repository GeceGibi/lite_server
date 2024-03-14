part of 'lite_server.dart';

mixin LiteLogger {
  final _cwd = Directory.current.path;
  late final logDir = Directory('$_cwd/logs');

  Future<void> logError(String content, {String? name}) async {}

  Future<void> log(String content, {String? prefix, String? suffix}) async {
    await logDir.create(recursive: true);
    final now = DateTime.now();
    var name = '${now.year}_${now.month}_${now.day}';

    if (prefix != null) {
      name = prefix + name;
    }

    if (suffix != null) {
      name = name + suffix;
    }

    final logFile = File('${logDir.path}/$name.log');

    await logFile.writeAsString(
        [
          now.toIso8601String(),
          content,
          '-' * 120,
        ].join('\n'),
        mode: FileMode.append);
  }

  void clearLogs() {
    if (logDir.existsSync()) {
      logDir.deleteSync(recursive: true);
    }
  }
}
