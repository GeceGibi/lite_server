import 'dart:io';

import 'package:lite_server/lite_server.dart';

final homeRoute = HttpRoute.get(
  '/',
  handler: (request, payload) {
    final cwd = Directory.current.path;
    request.response.file('$cwd/assets/web/index.html');
  },
);
