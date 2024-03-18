import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

class AuthService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> onRequest(HttpRequest request) {
    return HttpServiceBehavior.next(extra: {'auth': 1});
  }
}

class IpCheckService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> onRequest(HttpRequest request) {
    request.response.unauthorized();
    return HttpServiceBehavior.revoke();
  }
}
