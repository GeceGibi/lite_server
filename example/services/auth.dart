import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

class AuthService extends HttpController {
  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    return HttpControllerBehavior.next(extra: {'auth': 1});
  }
}

class IpCheckService extends HttpController {
  @override
  FutureOr<HttpControllerBehavior> onRequest(HttpRequest request) {
    request.response.unauthorized();
    return HttpControllerBehavior.revoke();
  }
}
