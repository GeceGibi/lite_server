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
    // Sanitize inputs
    if (requestPath.isEmpty || routePath.isEmpty) {
      return (false, {});
    }

    // Normalize paths
    final normalizedRequestPath =
        requestPath.startsWith('/') ? requestPath : '/$requestPath';
    final normalizedRoutePath =
        routePath.startsWith('/') ? routePath : '/$routePath';

    ///
    if (normalizedRequestPath.split('/').length !=
        normalizedRoutePath.split('/').length) {
      return (false, {});
    }

    // Check if route has dynamic parameters
    if (!pathPattern.hasMatch(normalizedRoutePath)) {
      return (normalizedRequestPath == normalizedRoutePath, {});
    }

    final routeMatcher = RegExp(
      normalizedRoutePath.replaceAllMapped(
        pathPattern,
        (match) => pathKey,
      ),
    );

    final params = <String, String>{};

    if (routeMatcher.hasMatch(normalizedRequestPath)) {
      for (final match in routeMatcher.allMatches(normalizedRequestPath)) {
        ///
        final keys = pathPattern.allMatches(normalizedRoutePath).toList();

        ///
        for (var g = 1; g < match.groupCount + 1; g++) {
          final key = keys[g - 1].group(1);
          final value = match.group(g);
          if (key != null && value != null) {
            params[key] = value;
          }
        }
      }

      return (true, params);
    }

    return (false, {});
  }
}
