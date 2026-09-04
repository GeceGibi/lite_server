part of 'lite_server.dart';

abstract final class _HttpUtils {
  /// Characters accepted inside a `<name>` placeholder.
  static const nameChars = r"[a-zA-Z0-9\-._~:@!$&'()*+,;=]+";

  /// Characters a path parameter may capture. `/` is deliberately excluded so
  /// a single parameter can never swallow more than one path segment, and `%`
  /// is included so percent encoded values still match.
  static const valueChars = r"[a-zA-Z0-9\-._~:@!$&'()*+,;=%]+";

  /// Matches a `<name>` placeholder inside a route path.
  static final pathPattern = RegExp('<($nameChars)>');

  static final _slashes = RegExp('/+');
  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');
  static final _separators = RegExp(r'[/\\]');

  /// Joins route segments into a single absolute path.
  static String normalizePath(List<String> paths) {
    return normalizeRequestPath(paths.join('/'));
  }

  /// Brings a request path into the same shape as a registered route path, so
  /// `/users/`, `//users` and `/users` all resolve to the same route.
  static String normalizeRequestPath(String path) {
    if (path.isEmpty) {
      return '/';
    }

    final collapsed =
        (path.startsWith('/') ? path : '/$path').replaceAll(_slashes, '/');

    if (collapsed.length > 1 && collapsed.endsWith('/')) {
      return collapsed.substring(0, collapsed.length - 1);
    }

    return collapsed;
  }

  /// Compiles [routePath] into an anchored pattern plus the ordered names of
  /// the parameters it captures, or `(null, [])` when the path has none.
  ///
  /// Literal parts are escaped so characters such as `.` keep their literal
  /// meaning instead of acting as a wildcard.
  static (RegExp?, List<String>) compile(String routePath) {
    final matches = pathPattern.allMatches(routePath).toList();

    if (matches.isEmpty) {
      return (null, const []);
    }

    final names = <String>[];
    final buffer = StringBuffer('^');
    var cursor = 0;

    for (final match in matches) {
      final name = match.group(1)!;

      if (names.contains(name)) {
        throw ArgumentError.value(
          routePath,
          'path',
          'duplicate path parameter <$name>',
        );
      }

      buffer
        ..write(RegExp.escape(routePath.substring(cursor, match.start)))
        ..write('($valueChars)');

      names.add(name);
      cursor = match.end;
    }

    buffer
      ..write(RegExp.escape(routePath.substring(cursor)))
      ..write(r'$');

    return (RegExp(buffer.toString()), names);
  }

  /// Matches [requestPath] against a pattern built by [compile], returning the
  /// decoded parameters or `null` when the path does not match.
  static Map<String, String>? matchParams(
    RegExp pattern,
    List<String> names,
    String requestPath,
  ) {
    final match = pattern.firstMatch(requestPath);

    if (match == null) {
      return null;
    }

    return {
      for (var index = 0; index < names.length; index++)
        names[index]: decodeSegment(match.group(index + 1) ?? ''),
    };
  }

  /// Percent decodes a single path segment, keeping the raw value when the
  /// encoding is malformed instead of failing the whole request.
  static String decodeSegment(String value) {
    if (!value.contains('%')) {
      return value;
    }

    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  /// Last path segment of [path], for both `/` and `\` separated paths.
  static String basename(String path) {
    final index = path.lastIndexOf(_separators);
    return index == -1 ? path : path.substring(index + 1);
  }

  /// Lower cased extension of [path] without the dot. Dotfiles such as `.env`
  /// are treated as having no extension.
  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final separator = path.lastIndexOf(_separators);

    if (dot <= separator + 1) {
      return '';
    }

    return path.substring(dot + 1).toLowerCase();
  }

  static String escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Strips control characters and clamps the length of [message] so a caller
  /// supplied string can never inject extra headers into the status line.
  static String sanitizeReasonPhrase(String message) {
    final sanitized = message.replaceAll(_controlChars, ' ').trim();

    if (sanitized.length <= 200) {
      return sanitized;
    }

    return sanitized.substring(0, 200);
  }

  /// Resolves the content type for [path], falling back to a binary type when
  /// the extension is unknown or the resolved value cannot be parsed.
  static ContentType contentTypeFor(String path, [String? override]) {
    final mimeType = override ?? lookupMimeType(path);

    if (mimeType == null) {
      return ContentType.binary;
    }

    try {
      return ContentType.parse(mimeType);
    } on FormatException {
      return ContentType.binary;
    }
  }
}
