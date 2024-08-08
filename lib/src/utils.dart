part of 'lite_server.dart';

interface class _HttpUtils {
  static const pathKey = r"([a-zA-Z0-9-._~:@!$&'()*+,;=]*)";
  static final pathPattern = RegExp('<$pathKey>');

  static String normalizePath(List<String> paths) {
    return paths.join('/').replaceAll('//', '/');
  }

  static (bool isMatched, Map<String, String> params) routeHasMatch(
    String requestPath,
    String routePath,
  ) {
    ///
    if (requestPath.split('/').length != routePath.split('/').length) {
      return (false, {});
    }

    final routeMatcher = RegExp(
      routePath.replaceAllMapped(
        pathPattern,
        (match) => pathKey,
      ),
    );

    final params = <String, String>{};

    if (routeMatcher.hasMatch(requestPath)) {
      for (final match in routeMatcher.allMatches(requestPath)) {
        ///
        final keys = pathPattern.allMatches(routePath).toList();

        ///
        for (var g = 1; g < match.groupCount + 1; g++) {
          params[keys[g - 1].group(1)!] = match.group(g)!;
        }
      }

      return (true, params);
    }

    return (false, {});
  }
}
