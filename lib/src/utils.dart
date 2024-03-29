part of 'lite_server.dart';

interface class HttpUtils {
  static const pathPatternGroup = '([a-zA-Z0-9_.]+)';
  static final pathPattern = RegExp('<$pathPatternGroup>');

  static String pathCorrection(String segment) {
    return switch (segment) {
      '' => '/',
      _ => segment,
    };
  }

  static String normalizePath(List<String> paths) {
    return paths.join('/').replaceAll('//', '/');
  }

  static (bool isMatched, Map<String, String> params) routeHasMatch(
    String requestPath,
    String mappedRoutePath,
  ) {
    final escapedRoutePath = RegExp.escape(mappedRoutePath);
    final dynamicPath = RegExp(escapedRoutePath.replaceAllMapped(
      pathPattern,
      (match) => pathPatternGroup,
    ));

    if (dynamicPath.hasMatch(requestPath)) {
      final key = pathPattern.firstMatch(escapedRoutePath)!.group(1)!;
      final value = dynamicPath.firstMatch(requestPath)!.group(1)!;

      return (true, {key: value});
    }

    return (false, {});
  }
}
