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

  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    8080
  );

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

```