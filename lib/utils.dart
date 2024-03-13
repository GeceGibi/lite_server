part of 'lite_server.dart';

interface class HttpUtils {
  static const pathPatternGroup = r'(\w+)';
  static final pathPattern = RegExp('<$pathPatternGroup>');

  static String pathCorrection(String segment) {
    return switch (segment) {
      '' => '/',
      _ => segment,
    };
  }

  static (bool isMatched, Map<String, String> params) routeHasMatch(
    String requestPath,
    String mappedRoutePath,
  ) {
    final dynamicPath = RegExp(RegExp.escape(mappedRoutePath).replaceAllMapped(
      pathPattern,
      (match) => pathPatternGroup,
    ));

    if (dynamicPath.hasMatch(requestPath)) {
      final key = pathPattern.firstMatch(mappedRoutePath)!.group(1)!;
      final value = dynamicPath.firstMatch(requestPath)!.group(1)!;

      return (true, {key: value});
    }

    return (false, {});
  }
}
