import 'package:lite_server/lite_server.dart';

final homeRoute = HttpRoute.get(
  '/',
  handler: (request, payload) {
    request.response.ok('HOME').close();
  },
);
