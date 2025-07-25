## LiteServer
Lightweight HttpServer wrapper for Dart.

## Features
- Easy to use
- Lightweight 
- Dynamic Path Support `/user/<id>`
- Nested Routes
- Static file support with security features
- MultipartFile support with security checks
- Support Custom Guard Controllers, manipulate request if need
- Request timeout protection
- Request size limits
- Directory traversal protection
- CORS support
- Comprehensive logging

## Security Features
- Request timeout protection (default: 30 seconds)
- Request size limits (default: 10MB)
- Directory traversal attack prevention
- File extension restrictions for static routes
- Input sanitization and validation
- Error handling with graceful degradation

## Usage
```dart
void main(List<String> arguments) async {
  final liteServer = LiteServer(
    routes: [
      homeRoute,
      HttpRoute.get(
        '/',
        handler: (request, payload) {
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
                  request.response.json([]);
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
        allowedExtensions: ['jpg', 'png', 'gif'], // Optional file restrictions
      ),
      HttpStaticRoute(
        '/web',
        directoryPath: 'assets/web/',
        defaultDocument: 'index.html',
      ),
    ],
    maxRequestSize: 5 * 1024 * 1024, // 5MB limit
    requestTimeout: Duration(seconds: 60), // 60 second timeout
  );

  for (var i = 0; i < 6; i++) {
    await Isolate.spawn(startServer, liteServer);
  }

  print(liteServer.routeMap.keys.join('\n'));
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
        allowedOrigins: {'http://localhost:3000', 'https://yourdomain.com'},
      ),
    ],
  );
}

## Configuration Options

### LiteServer Constructor
- `maxRequestSize`: Maximum request size in bytes (default: 10MB)
- `requestTimeout`: Request timeout duration (default: 30 seconds)

### HttpStaticRoute
- `allowedExtensions`: List of allowed file extensions for security
- `listDirectory`: Enable directory listing
- `defaultDocument`: Default document to serve

### LoggerController
- `level`: Logging level (all, errors, requests, none)
- `path`: Log directory path

### CorsOriginController
- `allowedOrigins`: Set of allowed origins
- `allowedMethods`: Set of allowed HTTP methods
- `allowedHeaders`: Set of allowed headers
- `maxAge`: CORS cache duration
- `allowCredentials`: Allow credentials
- `exposeHeaders`: Headers to expose