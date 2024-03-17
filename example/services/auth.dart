import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

class AuthService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
    return HttpServiceBehavior.next(extra: {'auth': 1});
  }
}

class IpCheckService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
    request.response.unauthorized().close();
    return HttpServiceBehavior.revoke();
  }
}
