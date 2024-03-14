import 'dart:convert';
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
      CorsOriginService(),
    ],
    routes: [
      homeRoute,
      HttpRoute.post(
        '/post',
        handler: (request, payload) async {
          print(jsonDecode(await request.readBodyAsString()));

          request.response.write('posted');
          request.response.close();
        },
      ),
      HttpRoute.post(
        '/upload',
        handler: (request, payload) async {
          await for (final entry in request.multipartData()) {
            print(entry.info);

            if (!entry.info.containsKey('content-type')) {
              print(utf8.decode(entry.bytes));
            }
          }

          request.response.write('uploaded');
          request.response.close();
        },
      ),
      HttpStaticRoute(
        '/images',
        directoryPath: 'assets/images/',
        listDirectory: true,
      ),
      HttpStaticRoute(
        '/web',
        directoryPath: 'assets/web/',
        defaultDocument: 'index.html',
      ),
    ],
  );
}
