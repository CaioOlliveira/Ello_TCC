import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String moduleOrigin(BuildContext context) {
  final query = GoRouterState.of(context).uri.queryParameters;
  final from = query['from'];
  final path = GoRouterState.of(context).uri.path;

  if (from == 'dashboard' || from == 'monitoramento') return from!;
  if (path == '/dashboard') return 'dashboard';
  return 'monitoramento';
}

String moduleBackRoute(BuildContext context) {
  return moduleOrigin(context) == 'dashboard' ? '/dashboard' : '/monitoramento';
}

String routeWithCurrentOrigin(BuildContext context, String route) {
  return routeWithOrigin(route, moduleOrigin(context));
}

String routeWithOrigin(String route, String origin) {
  final separator = route.contains('?') ? '&' : '?';
  return '$route${separator}from=$origin';
}

String profileRouteFromModule(BuildContext context, String module) {
  return Uri(
    path: '/perfil',
    queryParameters: {
      'from': module,
      'moduleFrom': moduleOrigin(context),
    },
  ).toString();
}
