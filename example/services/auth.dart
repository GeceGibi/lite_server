import 'dart:io';

import 'package:lite_server/lite_server.dart';

class AuthService extends HttpService {
  @override
  handleRequest(HttpRequest request) {
    return (request, {'auth': 1});
  }
}

class IpCheckService extends HttpService {
  @override
  handleRequest(HttpRequest request) {
    // throw HttpException(
    //   message: 'Fuck off',
    //   statusCode: HttpStatus.unauthorized,
    // );

    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write('NOT ALLOWED');
    request.response.close();

    return (request, null);
  }
}

class LogService extends HttpService {
  @override
  handleRequest(HttpRequest request) {
    final now = DateTime.now();
    print('$now: ${request.method} | ${request.uri}');

    return (request, null);
  }
}
