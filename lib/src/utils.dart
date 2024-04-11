part of 'lite_server.dart';

interface class _HttpUtils {
  static const pathPatternGroup = r"([a-zA-Z0-9-._~:@!$&'()*+,;=]*)";
  static final pathPattern = RegExp('<$pathPatternGroup>');

  static String normalizePath(List<String> paths) {
    return paths.join('/').replaceAll('//', '/');
  }

  static (bool isMatched, Map<String, String> params) routeHasMatch(
    String requestPath,
    String mappedRoutePath,
  ) {
    final escapedRoutePath = RegExp.escape(mappedRoutePath);
    final dynamicPath = RegExp(
      escapedRoutePath.replaceAllMapped(
        pathPattern,
        (match) => pathPatternGroup,
      ),
    );

    if (dynamicPath.hasMatch(requestPath)) {
      final key = pathPattern.firstMatch(escapedRoutePath)!.group(1)!;
      final value = dynamicPath.firstMatch(requestPath)!.group(1)!;

      return (true, {key: value});
    }

    return (false, {});
  }
}
