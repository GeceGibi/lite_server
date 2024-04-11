import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:lite_server/lite_server.dart';
import 'package:lite_server/src/lite_server.dart';

import 'routes/home.dart';

void main(List<String> arguments) async {
  final liteServer = LiteServer(
    controllers: [
      LoggerController(),
      CorsOriginController(
        allowedMethods: {'GET', 'POST', 'OPTIONS'},
      ),
    ],
    routes: [
      homeRoute,
      HttpRoute.get(
        '/',
        handler: (request, payload) {
          throw Exception('Error test');
          // request.response.redirect(Uri(path: '/api/users'));
          final cwd = Directory.current.path;
          request.response.file('$cwd/assets/web/images/512.png');
        },
        routes: [
          HttpRoute.get(
            'api',
            routes: [
              HttpRoute.get(
                'users',
                handler: (request, payload) {
                  request.response.json(<Object>[]);
                },
              ),
            ],
          ),
        ],
      ),
      HttpRoute.post(
        '/user/<id>',
        handler: (request, payload) async {
          print(jsonDecode(await request.readBodyAsString()));
          await request.response.json(payload.pathParameters);
        },
      ),
      HttpRoute.get(
        '/user/<id>',
        handler: (request, payload) async {
          await request.response.json(payload.pathParameters);
        },
      ),
      HttpRoute.post(
        '/post',
        handler: (request, payload) async {
          print(jsonDecode(await request.readBodyAsString()));
          await request.response.ok('posted');
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

          await request.response.ok('uploaded');
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

  print(liteServer.routeMap.keys.join('\n'));
  // await startServer(liteServer);

  await Future<void>.delayed(const Duration(seconds: 500));
}

Future<void> startServer(LiteServer liteServer) async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    9080,
    shared: true,
  )
    ..autoCompress = true
    ..serverHeader = Isolate.current.hashCode.toString();

  liteServer.listen(server);
}
