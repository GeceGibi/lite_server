## LiteServer

Lightweight `HttpServer` wrapper for Dart.

## Features

- Easy to use
- Lightweight
- Dynamic path support `/user/<id>`
- Nested routes with inherited controllers
- Method aware routing: `GET /user/<id>` and `POST /user/<id>` are separate routes
- Static file serving with streaming and conditional requests
- Multipart uploads with size limits
- Custom guard controllers that can rewrite or reject a request
- Request timeout protection
- Request size limits
- Directory traversal protection
- CORS support
- Request and error logging

## Security Features

- Request timeout protection (default: 30 seconds)
- Request size limits (default: 10MB), enforced while the body is read so a
  chunked upload without a declared length cannot bypass them
- Directory traversal prevention: every path segment is decoded and validated,
  and resolved files are checked against the real directory so symlinks cannot
  point outside of it
- File extension restrictions for static routes
- Directory listings escape file names and hide dotfiles
- CORS responses echo a single allowed origin and never pair `*` with
  credentials
- Response messages are stripped of control characters, so they cannot inject
  headers into the status line

## Usage

```dart
import 'dart:io';
import 'dart:isolate';

import 'package:lite_server/lite_server.dart';

void main(List<String> arguments) async {
  final liteServer = LiteServer(
    routes: [
      HttpRoute.get(
        '/',
        handler: (request, payload) => request.response.html('<h1>Home</h1>'),
        routes: [
          HttpRoute.get(
            'api',
            routes: [
              HttpRoute.get(
                'users',
                handler: (request, payload) => request.response.json(<Object>[]),
              ),
            ],
          ),
        ],
      ),
      HttpRoute.get(
        '/user/<id>',
        handler: (request, payload) => request.response.json(
          {'id': payload.parameter('id')},
        ),
      ),
      HttpRoute.post(
        '/user/<id>',
        handler: (request, payload) async {
          final body = await request.readBodyAsJson<Map<String, Object?>>();
          await request.response.json({'id': payload.parameter('id'), ...body});
        },
      ),
      HttpRoute.post(
        '/upload',
        handler: (request, payload) async {
          await for (final part in request.multipartData()) {
            if (part.isFile) {
              print('${part.filename}: ${part.bytes.length} bytes');
            } else {
              print('${part.name} = ${part.text()}');
            }
          }

          await request.response.ok(body: 'uploaded');
        },
      ),
      HttpStaticRoute(
        '/images',
        directoryPath: 'assets/images/',
        listDirectory: true,
        allowedExtensions: ['jpg', 'png', 'gif'],
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
        allowedOrigins: {'http://localhost:3000', 'https://yourdomain.com'},
      ),
    ],
  );
}
```

## Routing

Top level paths start with `/`, nested paths do not. A route without a handler
only groups its children, and controllers are inherited by everything nested
under a route.

A `<name>` placeholder matches exactly one path segment. Values are percent
decoded, so `/user/John%20Doe` gives `id` the value `John Doe`. Matching goes
from most to least specific: literal paths first, then paths with placeholders,
then static file mounts by longest prefix. Trailing slashes are ignored.

Registering the same path and method twice throws an `ArgumentError`, as does
nesting a path incorrectly or reusing a placeholder name in one path.

When a path matches but the method does not, the response is `405` with an
`Allow` header listing the methods that are registered.

## Configuration Options

### LiteServer

- `routes`: The route tree
- `maxRequestSize`: Maximum request body size in bytes (default: 10MB)
- `requestTimeout`: Request timeout duration (default: 30 seconds)
- `onRouteNotFound`: Replaces the default `404` response
- `onError`: Replaces the default `500` response

`listen` returns the `StreamSubscription` it created, so serving can be stopped
without closing the `HttpServer`. Pass `logStartup: false` to silence the
startup line.

### HttpStaticRoute

- `directoryPath`: Directory to serve
- `allowedExtensions`: Allowed file extensions, with or without a leading dot
- `listDirectory`: Enable directory listing
- `defaultDocument`: Document served for a directory

Answers `GET` and `HEAD`, sends `Last-Modified` and replies `304` to an up to
date `If-Modified-Since`.

### LoggerController

- `level`: What is written to disk (`all`, `errors`, `requests`, `none`)
- `path`: Log directory path (default: `./logs`)
- `printLogs`: Mirror lines to stdout (default: `true`)

Log files are created on first write and roll over daily. Nothing is written to
disk while `level` is `LogLevel.none`.

### CorsOriginController

- `allowedOrigins`: Set of allowed origins, or `{'*'}` for any
- `allowedMethods`: Set of allowed HTTP methods
- `allowedHeaders`: Set of allowed headers
- `maxAge`: Preflight cache duration
- `allowCredentials`: Allow credentials
- `exposeHeaders`: Headers to expose

## Request Helpers

- `readBodyAsBytes()`, `readBodyAsString()`, `readBodyAsJson<T>()`
- `multipartData()`, `isMultipart`

Body readers stop and throw `HttpRequestTooLargeException` once the limit is
reached, which `LiteServer` turns into a `413` response.

## Response Helpers

- `ok()`, `json()`, `text()`, `html()`, `file()`, `status()`
- `badRequest()`, `unauthorized()`, `forbidden()`, `notFound()`,
  `methodNotAllowed()`, `internalServerError()`

Every helper closes the response. A `message` without a `body` is sent as the
body as well, because HTTP reason phrases are invisible to most clients.
