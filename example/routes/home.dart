import 'package:lite_server/lite_server.dart';

import '../services/auth.dart';

final homeRoute = HttpRoute.get(
  '/',
  handler: (request, payload) {
    request.response.write('HOME');
    request.response.close();
  },
);

final adminRoute = HttpRoute.get(
  '/admin',
  services: [
    IpCheckService(),
  ],
  handler: (request, payload) {
    request.response.write(request.uri.path);
    request.response.close();
  },
  routes: [
    HttpRoute.get(
      'edit/<user>',
      handler: (request, payload) {
        request.response.write(payload.pathParameters.toString());
        request.response.close();
      },
    ),
    HttpRoute.get(
      'create',
      handler: (request, payload) {
        request.response.write(request.uri.path);
        request.response.close();
      },
      routes: [
        HttpRoute.get(
          'user',
          handler: (request, payload) {
            request.response.write(request.uri.path);
            request.response.close();
          },
        ),
        HttpRoute.get(
          'project',
          handler: (request, payload) {
            request.response.write(request.uri.path);
            request.response.close();
          },
        )
      ],
    )
  ],
);
