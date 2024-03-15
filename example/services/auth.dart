import 'dart:async';
import 'dart:io';

import 'package:lite_server/lite_server.dart';

class AuthService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
    return HttpServiceBehavior.moveOn(extra: {'auth': 1});
  }
}

class IpCheckService extends HttpService {
  @override
  FutureOr<HttpServiceBehavior> handleRequest(HttpRequest request) {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write('NOT ALLOWED');
    request.response.close();

    return HttpServiceBehavior.moveOn();
  }
}
