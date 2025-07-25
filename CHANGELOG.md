# Changelog

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


