# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2026-10-15

### Added

- `HttpErrorCallback` typedef for server error handlers (`onError`, `listen`).
- Optional `maxSize` parameter to `HttpRequest.readBodyAsString()` to override the default request body size limit.

### Refactored

- Controller pipeline execution in `LiteServer` unified into a single helper (`_runControllers`).

## [0.4.1] - 2026-09-10

### Breaking Changes

- Route constructors take a named `path` argument instead of a positional one:
  `HttpRoute.get(path: '/users', ...)` and
  `HttpStaticRoute(path: '/assets', directoryPath: ...)`.

## [0.4.0] - 2026-09-04

### Breaking Changes

- Path parameters must be non-empty, so `/user/` no longer matches `/user/<id>`.
- Invalid route configuration throws `ArgumentError` instead of `Exception`.
  Registering the same path and method twice is rejected at startup.
- Static routes serve `GET` and `HEAD` by default (was `GET` only).

### Fixed

- Routes are keyed by path **and** method. `GET /user/<id>` and `POST /user/<id>`
  used to overwrite each other in the route map, leaving one unreachable behind
  a `405`.
- Request size limits are enforced while the body is read. A chunked request
  without `Content-Length` previously bypassed the limit entirely.
- Path parameters accept and decode percent-encoded values
  (`/user/John%20Doe` → `id: John Doe`).
- Literal characters in route paths are escaped (`/report.json` no longer
  matches `/reportxjson`).
- A path parameter can no longer capture across `/`.
- The request timeout timer is always cancelled (early returns previously
  leaked a timer that fired ~30s later).
- Errors raised after the response is closed no longer produce an unhandled
  asynchronous error while trying to send a `500`.
- `onError` passed to `listen` is used as a fallback error handler (it was
  accepted and ignored).
- Static routes only match the mount path and paths under it
  (`/imagesEVIL` no longer hits `/images`).
- Nested static routes no longer strip the wrong path prefix.
- Directory listings HTML-escape file names and hide dotfiles (e.g. `.env`).
- CORS: `Access-Control-Allow-Origin` echoes a single allowed origin, never
  pairs `*` with credentials, and sends `Vary: Origin` when the origin varies.
- Response messages are stripped of control characters (no status-line header
  injection).
- `status()` keeps a content type set earlier instead of clearing it.
- `LiteServerLogger` file handles are per-instance and roll over daily (they
  were static and shared across loggers).
- `LoggerController` does not create a log directory when nothing will be
  written.
- Multipart parts use `BytesBuilder` and stream as they arrive (no O(n²)
  rebuild per chunk).
- `content-disposition` splits on the first `=` only (file names with `=`
  survive).
- `isMultipart` checks the media type, not only a boundary parameter.
- Unknown MIME types serve as `application/octet-stream` instead of `500`.
- `analysis_options.yaml` lint disables moved to `analyzer: errors:` so they
  merge with the included rule set.

### Added

- `HttpRoute.put`, `.patch`, `.delete`, `.head`, and `.options`
- `HttpRoutePayload.path`, `.parameter()`, and `.extra<T>()`
- `readBodyAsBytes()`, `readBodyAsJson<T>()`
- `HttpMultiPartData.name`, `.filename`, `.contentType`, `.isFile`, and `.text()`
- `response.text()`, and optional `message` on error helpers
- `HttpRequestTooLargeException` and `HttpMultipartException`
- `LoggerController.printLogs` and `LiteServerLogger.close()`
- `405` responses include an `Allow` header
- Static routes honour `If-Modified-Since` / `Last-Modified` (`304`)
- Test suite for routing, request handling, static-file security, CORS,
  logging, and multipart parsing

### Changed

- Files are streamed instead of buffered in memory (`response.file()` and
  static routes).
- Route patterns are compiled once at startup.
- `listen` returns its `StreamSubscription` and accepts `logStartup`.
- Method matching is case-insensitive.
- Trailing slashes are ignored when matching.
- A `message` without a `body` is written as the response body.

## [0.3.0] - 2024-12-19

- Add request timeout protection (30s default)
- Add request size limits (10MB default)
- Add directory traversal attack prevention
- Add file extension restrictions for static routes
- Add forbidden response helper
- Optimize route matching performance
- Improve error handling and logging
- Update dependencies

## [0.2.4] - 2024-11-15

- Updated dependencies.
- Updated `response.ok()`

## [0.2.3] - 2024-10-20

- Fixed nested route multiple dynamic path parameter parse bug ex. `/<foo>/<bar>/<deep>/<path>/...`

## [0.2.1] - 2024-09-10

- Updated Readme.md

## [0.2.0] - 2024-08-25

- Updated `LoggerController` work logic;
- Relocated `LiteServer(controllers: [...])` => `LiteServer(...).listen(httpServer, controllers: [...])`

## [0.1.5] - 2024-07-15

- Updated `CorsOriginController` `OPTIONS` method response;

## [0.1.4] - 2024-06-30

- Updated LoggerController

## [0.1.3] - 2024-06-10

- Updated Request Logger
- Renamed `HttpService` to `HttpController` and update error handle logic
- Renamed `HttpServiceBehavior` to `HttpControllerBehavior`

## [0.1.2] - 2024-05-20

- Updated Example

## [0.1.1] - 2024-05-05

- Fixed typos
- Fixed minor issues

## [0.1.0] - 2024-04-15

- Fixed allowed methods check logic

## [0.0.9] - 2024-03-25

- Added missing `service` argument for `HttpStaticRoute`

## [0.0.8] - 2024-03-10

- Updated `CorsOriginService`

## [0.0.7] - 2024-02-20

- Fixed null-check issue.

## [0.0.6] - 2024-02-05

- Updated response helper extension methods. `Not need to call .close() anymore`
- Updated logger service

## [0.0.5] - 2024-01-15

- Renamed `HttpServiceBehavior.modeOn` => `HttpServiceBehavior.next`
- Renamed `HttpServiceBehavior.cutOff` => `HttpServiceBehavior.revoke`
- Updated helpers extensions

## [0.0.4] - 2024-01-05

- Updated Logger `printLogs` logic

## [0.0.3] - 2023-12-20

- Moved logging params to LoggerService
- Added `onError` handler to services
- HttpServices now return `HttpServiceBehavior`

## [0.0.2] - 2023-12-10

- Updated LiteServer initialize method

## [0.0.1] - 2023-12-01

- Initial version.
