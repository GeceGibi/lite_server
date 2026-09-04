// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';

import 'package:lite_server/lite_server.dart';

import 'routes/home.dart';

void main(List<String> arguments) async {
  final liteServer = LiteServer(
    routes: [
      homeRoute,
      HttpRoute.get(
        '/api',
        routes: [
          HttpRoute.get(
            'users',
            handler: (request, payload) => request.response.json(<Object>[]),
          ),
        ],
      ),
      HttpRoute.get(
        '/user/<id>',
        handler: (request, payload) =>
            request.response.json(payload.pathParameters),
        routes: [
          HttpRoute.get(
            '<pack>',
            handler: (request, payload) =>
                request.response.json(payload.pathParameters),
            routes: [
              HttpRoute.get(
                '<dept>',
                handler: (request, payload) =>
                    request.response.json(payload.pathParameters),
              ),
            ],
          ),
        ],
      ),
      HttpRoute.post(
        '/user/<id>',
        handler: (request, payload) async {
          final body = await request.readBodyAsJson<Map<String, Object?>>();

          await request.response.json({
            'id': payload.parameter('id'),
            'body': body,
          });
        },
      ),
      HttpRoute.post(
        '/upload',
        handler: (request, payload) async {
          final received = <String>[];

          await for (final part in request.multipartData()) {
            received.add(
              part.isFile
                  ? '${part.filename} (${part.bytes.length} bytes)'
                  : '${part.name}=${part.text()}',
            );
          }

          await request.response.json(received);
        },
      ),
      HttpStaticRoute(
        '/images',
        directoryPath: 'assets/images/',
        listDirectory: true,
        allowedExtensions: {'jpg', 'png', 'gif'},
      ),
      HttpStaticRoute(
        '/web',
        directoryPath: 'assets/web/',
        defaultDocument: 'index.html',
      ),
    ],
    maxRequestSize: 5 * 1024 * 1024,
    requestTimeout: const Duration(seconds: 60),
  );

  print(liteServer.routeMap.keys.join('\n'));

  for (var i = 0; i < 5; i++) {
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

  liteServer.listen(
    server,
    controllers: [
      LoggerController(level: LogLevel.errors),
      CorsOriginController(
        allowedMethods: {'GET', 'POST', 'OPTIONS'},
        allowedOrigins: {'http://localhost:3000'},
      ),
    ],
  );
}
