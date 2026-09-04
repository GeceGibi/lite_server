import 'package:lite_server/lite_server.dart';

final homeRoute = HttpRoute.get(
  '/',
  handler: (request, payload) {
    return request.response.file('assets/web/index.html');
  },
);
