import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

/// Passes every request through, publishing a value the handler can read from
/// [HttpRoutePayload.extras].
class AuthController extends HttpController {
  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    return const HttpControllerBehavior.next(extra: {'auth': 1});
  }
}

/// Cuts the request off before it reaches the handler.
class IpCheckController extends HttpController {
  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) async {
    await request.response.unauthorized(message: 'Blocked address');
    return const HttpControllerBehavior.revoke();
  }
}
