# Changelog

## [0.4.0] - 2026-09-04

### Fixed

- Routes are now keyed by path *and* method. `GET /user/<id>` and
  `POST /user/<id>` used to overwrite each other in the route map, leaving one
  of them unreachable behind a `405`.
- The request size limit is enforced while the body is read. A chunked request
  without a `Content-Length` previously bypassed it completely.
- Path parameters accept and decode percent encoded values, so
  `/user/John%20Doe` matches `/user/<id>` and yields `John Doe`.
- Literal characters in a route path are escaped, so `/report.json` no longer
  matches `/reportxjson`.
- A path parameter can no longer capture across `/`.
- The request timeout timer is always cancelled. Returning early on an
  oversized request used to leak a timer that fired 30 seconds later.
- An error raised after the response was closed no longer produces an
  unhandled asynchronous error while trying to send a `500`.
- `onError` passed to `listen` was accepted and then ignored; it is now used as
  a fallback error handler.
- Static routes matched any path with the mount as a prefix, so `/imagesEVIL`
  resolved to the `/images` mount. Only the mount itself and paths below it
  match now.
- Static routes nested under a parent route stripped the wrong prefix and could
  never find their files.
- Directory listings escape file names, closing an HTML injection hole, and
  hide dotfiles such as `.env`.
- `Access-Control-Allow-Origin` carries a single origin instead of the whole
  allow list, and is never sent as `*` together with
  `Access-Control-Allow-Credentials: true`. Responses that vary by origin now
  send `Vary: Origin`.
- Response messages are stripped of control characters, so a message can no
  longer inject headers into the status line.
- `status()` keeps a content type set earlier instead of clearing it.
- `LiteServerLogger` used static file handles, so two loggers wrote to one
  file. Handles are per instance now and are rolled over daily instead of
  being pinned to the day the server started.
- `LoggerController` no longer creates a log directory when nothing will be
  written to it.
- Multipart parts are collected through a `BytesBuilder` instead of being
  rebuilt per chunk, removing quadratic cost on large uploads, and parts are
  streamed as they arrive.
- `content-disposition` values split on their first `=` only, so a file name
  containing `=` survives.
- `isMultipart` checks the media type instead of only looking for a boundary.
- An unknown MIME type serves as `application/octet-stream` rather than
  failing with a `500`.
- `analysis_options.yaml` disabled lints through a rule map, which replaced the
  included rule set instead of merging with it. Disables moved to
  `analyzer: errors:`.

### Added

- `HttpRoute.put`, `.patch`, `.delete`, `.head` and `.options`
- `HttpRoutePayload.path`, `.parameter()` and `.extra<T>()`
- `readBodyAsBytes()`, `readBodyAsJson<T>()`
- `HttpMultiPartData.name`, `.filename`, `.contentType`, `.isFile` and `.text()`
- `response.text()`, and an optional `message` on the error helpers
- `HttpRequestTooLargeException` and `HttpMultipartException`
- `LoggerController.printLogs` and `LiteServerLogger.close()`
- `405` responses carry an `Allow` header
- Static routes answer `HEAD`, send `Last-Modified` and honour
  `If-Modified-Since`
- A test suite covering routing, request handling, static file security, CORS,
  logging and multipart parsing

### Changed

- Files are streamed instead of being read into memory, both by
  `response.file()` and by static routes.
- Route patterns are compiled once at startup rather than rebuilt per request.
- `listen` returns its `StreamSubscription` and takes `logStartup`.
- Method matching is case insensitive.
- Trailing slashes are ignored when matching.
- A `message` without a `body` is written as the response body.
- Path parameters must be non-empty, so `/user/` no longer matches
  `/user/<id>`.
- Invalid route configuration throws `ArgumentError` instead of `Exception`,
  and a duplicate path and method pair is now rejected.
- Static routes serve `GET` and `HEAD` by default.

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


