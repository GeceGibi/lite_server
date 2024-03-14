import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:lite_server/lite_server.dart';

import 'services/auth.dart';

void main(List<String> arguments) async {
  final liteServer = LiteServer(
    cleanLogsOnStart: true,
    logRequests: true,
    logErrors: true,
    services: [
      LogService(),
      CorsOriginService(),
    ],
    routes: [
      HttpRoute.post(
        '/user/<id>',
        handler: (request, payload) async {
          print(jsonDecode(await request.readBodyAsString()));
          request.response.json(jsonEncode(payload.pathParameters));
        },
      ),
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

  for (var i = 0; i < 6; i++) {
    await Isolate.spawn(startServer, liteServer);
  }

  await startServer(liteServer);
}

Future<void> startServer(LiteServer liteServer) async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    9080,
    shared: true,
  )
    ..autoCompress = true
    ..serverHeader = Isolate.current.hashCode.toString();

  liteServer.attach(server);
}
