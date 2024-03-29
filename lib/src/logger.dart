part of 'lite_server.dart';

mixin LiteLogger {
  final _cwd = Directory.current.path;
  late var logDir = Directory('$_cwd/logs');

  Future<void> logError(String content, {String? name}) async {}

  Future<void> log(
    String content, {
    String? name,
    String? prefix,
    String? suffix,
  }) async {
    await logDir.create(recursive: true);
    final now = DateTime.now();

    name = name ?? '${now.year}_${now.month}_${now.day}';

    if (prefix != null) {
      name = prefix + name;
    }

    if (suffix != null) {
      name = name + suffix;
    }

    final logFile = File('${logDir.path}/$name.log');

    final openedLogFile = await logFile.open(mode: FileMode.append);
    await openedLogFile.writeString(content);
  }

  void clearLogs() {
    if (logDir.existsSync()) {
      logDir.deleteSync(recursive: true);
    }
  }
}
