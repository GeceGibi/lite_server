## LiteServer
Lightweight Http server for Dart.

## Features
- Easy to use
- Lightweight 
- Dynamic Path `/user/<id>`
- Nested Routes
- Static file handler
- MultipartFile support
- Support Custom Guard Services, manipulate request if need. 

## Usage
```dart
void main(List<String> arguments) async {
  final liteServer = LiteServer(
    services: [
      LoggerService(),
      CorsOriginService(),
    ],
    routes: [
      HttpRoute.get(
        '/',
        handler: (request, payload) {
          await request.response.redirect(Uri(path: '/api/users'));
        },
        routes: [
          HttpRoute.get(
            'api',
            routes: [
              HttpRoute.get(
                'users',
                handler: (request, payload) async {
                  await request.response.json('[]');
                },
              ),
            ],
          )
        ],
      ),
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

```