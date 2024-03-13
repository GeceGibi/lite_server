import 'dart:io';
import 'package:lite_server/lite_server.dart';

import 'routes/home.dart';
import 'services/auth.dart';

void main(List<String> arguments) async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    9080,
    shared: true,
  );

  server.autoCompress = true;

  LiteServer.attach(
    server,
    cleanLogsOnStart: true,
    logRequests: true,
    logErrors: true,
    services: [
      LogService(),
    ],
    routes: [
      homeRoute,
      adminRoute,
    ],
  );
}
