## 0.2.3
- Fixed nested route multiple dynamic path parameter parse bug ex. `/<foo>/<bar>/<deep>/<path>/...`

## 0.2.1
- Updated Readme.md

## 0.2.0
- Updated `LoggerController` work logic;
- Relocated `LiteServer(controllers: [...])` => `LiteServer(...).listen(httpServer, controllers: [...])`

## 0.1.5
- Updated `CorsOriginController` `OPTIONS` method response;

## 0.1.4
- Updated LoggerController

## 0.1.3
- Updated Request Logger
- Renamed `HttpService` to `HttpController` and update error handle logic
- Renamed `HttpServiceBehavior` to `HttpControllerBehavior`


## 0.1.2
- Updated Example

## 0.1.1
- Fixed typos
- Fixed minor issues

## 0.1.0
- Fixed allowed methods check logic

## 0.0.9
- Added missing `service` argument for `HttpStaticRoute` 

## 0.0.8
- Updated `CorsOriginService` 

## 0.0.7
- Fixed null-check issue.

## 0.0.6
- Updated response helper extension methods. `Not need to call .close() anymore`
- Updated logger service

## 0.0.5
- Renamed `HttpServiceBehavior.modeOn` => `HttpServiceBehavior.next`
- Renamed `HttpServiceBehavior.cutOff` => `HttpServiceBehavior.revoke`
- Updated helpers extensions

## 0.0.4
- Updated Logger `printLogs` logic

## 0.0.3
- Moved logging params to LoggerService
- Added `onError` handler to services
- HttpServices now return `HttpServiceBehavior`

## 0.0.2
- Updated LiteServer initialize method

## 0.0.1
- Initial version.


