import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps the route history for screens navigated with [GoRouter.go].
///
/// `go` replaces the Navigator stack, so Android's system back button needs
/// this lightweight history to behave like the visible back arrow.
class AppBackNavigation {
  AppBackNavigation._();

  static final instance = AppBackNavigation._();
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final shellNavigatorKey = GlobalKey<NavigatorState>();

  final List<String> _previousLocations = [];
  GoRouter? _router;
  String? _currentLocation;
  bool _nextNavigationIsBack = false;
  bool _handlingSystemBack = false;
  bool _localBackAvailable = false;

  void setLocalBackAvailable(bool available) {
    _localBackAvailable = available;
  }

  void attach(GoRouter router) {
    if (identical(_router, router)) return;

    _router?.routerDelegate.removeListener(_onRouterChanged);
    _previousLocations.clear();
    _router = router;
    _currentLocation = _locationOf(router);
    router.routerDelegate.addListener(_onRouterChanged);
  }

  void markAppBackButtonPressed() {
    _nextNavigationIsBack = true;
    scheduleMicrotask(() => _nextNavigationIsBack = false);
  }

  /// Whether the app can consume a system-back request without closing the
  /// Android activity.
  bool get canHandleSystemBack {
    final router = _router;
    return router != null &&
        (rootNavigatorKey.currentState?.canPop() == true ||
            shellNavigatorKey.currentState?.canPop() == true ||
            _localBackAvailable ||
            _previousLocations.isNotEmpty ||
            _fallbackBackDestination(_locationOf(router)) != null);
  }

  Future<bool> handleSystemBack() async {
    final router = _router;
    if (router == null) return false;

    // maybePop also lets PopScope handle an in-page form or tab before the
    // route changes. Check the root first for dialogs and MaterialPageRoutes.
    for (final navigatorKey in [rootNavigatorKey, shellNavigatorKey]) {
      final navigator = navigatorKey.currentState;
      if (navigator != null && await navigator.maybePop()) return true;
    }

    if (_previousLocations.isNotEmpty) {
      final destination = _previousLocations.removeLast();
      _handlingSystemBack = true;
      router.go(destination);
      return true;
    }

    final destination = _fallbackBackDestination(_locationOf(router));
    if (destination == null) return false;
    _handlingSystemBack = true;
    router.go(destination);
    return true;
  }

  void _onRouterChanged() {
    final router = _router;
    if (router == null) return;

    final nextLocation = _locationOf(router);
    final currentLocation = _currentLocation;
    if (nextLocation == currentLocation) return;

    if (!_shouldTrack(nextLocation)) {
      _previousLocations.clear();
      _currentLocation = nextLocation;
      _nextNavigationIsBack = false;
      _handlingSystemBack = false;
      return;
    }

    if (_handlingSystemBack) {
      _handlingSystemBack = false;
      _currentLocation = nextLocation;
      return;
    }

    if (_nextNavigationIsBack) {
      _nextNavigationIsBack = false;
      final previousIndex = _previousLocations.lastIndexOf(nextLocation);
      if (previousIndex >= 0) {
        _previousLocations.removeRange(
          previousIndex,
          _previousLocations.length,
        );
      }
      _currentLocation = nextLocation;
      return;
    }

    // A GoRouter.push followed by pop returns to the top history entry.
    // Remove it instead of recording the popped page as a new destination.
    if (_previousLocations.isNotEmpty &&
        _previousLocations.last == nextLocation) {
      _previousLocations.removeLast();
      _currentLocation = nextLocation;
      return;
    }

    if (currentLocation != null && _shouldTrack(currentLocation)) {
      _previousLocations.add(currentLocation);
    }
    _currentLocation = nextLocation;
  }

  String _locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  bool _shouldTrack(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return path != '/' && path != '/login';
  }

  String? _fallbackBackDestination(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    if (path == '/' || path == '/login' || path == '/dashboard') return null;

    if (path == '/agenda/historico') return '/agenda';
    if (path == '/equipamentos/historico') return '/equipamentos';
    if (path.startsWith('/historico/')) {
      return '/${path.substring('/historico/'.length)}';
    }
    if (path.startsWith('/chat/')) return '/chat';
    if (path.startsWith('/perfil/')) {
      return path.substring(0, path.lastIndexOf('/'));
    }
    if (path.startsWith('/idosos/')) return '/idosos';
    if (path == '/permissoes/detalhes') return '/permissoes';
    if (path == '/permissoes') return '/perfil/seguranca';
    if (path == '/idoso/acessos') return '/idoso/perfil';
    if (path == '/idoso/perfil') return '/dashboard';
    if (path == '/idosos') return '/login';
    if (path == '/monitoramento') return '/dashboard';

    final from = uri?.queryParameters['from'];
    return switch (from) {
      'dashboard' => '/dashboard',
      'monitoramento' => '/monitoramento',
      _ => path == '/perfil' ? '/dashboard' : '/monitoramento',
    };
  }
}

/// Receives Android's native back event before GoRouter tries to pop routes.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher(this._navigation);

  final AppBackNavigation _navigation;
  bool _handlingPredictiveBackGesture = false;

  @override
  Future<bool> didPopRoute() async {
    if (await _navigation.handleSystemBack()) return true;
    return super.didPopRoute();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    // On Android 13+, swiping from a screen edge is delivered through the
    // predictive-back callbacks instead of didPopRoute. Claim it whenever the
    // app has a Navigator entry or an in-app history entry to return to.
    _handlingPredictiveBackGesture = _navigation.canHandleSystemBack;
    return _handlingPredictiveBackGesture;
  }

  @override
  void handleCommitBackGesture() {
    if (_handlingPredictiveBackGesture) {
      unawaited(_navigation.handleSystemBack());
    }
    _handlingPredictiveBackGesture = false;
  }

  @override
  void handleCancelBackGesture() {
    _handlingPredictiveBackGesture = false;
  }
}
