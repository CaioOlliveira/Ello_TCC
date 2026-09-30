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

  final List<String> _previousLocations = [];
  GoRouter? _router;
  String? _currentLocation;
  bool _nextNavigationIsBack = false;
  bool _handlingSystemBack = false;

  void attach(GoRouter router) {
    if (identical(_router, router)) return;

    _router = router;
    _currentLocation = _locationOf(router);
    router.routerDelegate.addListener(_onRouterChanged);
  }

  void markAppBackButtonPressed() {
    _nextNavigationIsBack = true;
  }

  /// Whether the app can consume a system-back request without closing the
  /// Android activity.
  bool get canHandleSystemBack {
    final router = _router;
    return router != null && (router.canPop() || _previousLocations.isNotEmpty);
  }

  bool handleSystemBack() {
    final router = _router;
    if (router == null) return false;

    // Screens opened with `push` still have a Navigator entry. Pop that
    // entry first so the user returns to the immediately previous screen.
    if (router.canPop()) {
      router.pop();
      return true;
    }

    final originDestination = _originBackDestination(_locationOf(router));
    if (originDestination != null) {
      _removeDestinationFromHistory(originDestination);
      _handlingSystemBack = true;
      router.go(originDestination);
      return true;
    }

    if (_previousLocations.isEmpty) return false;

    final destination = _previousLocations.removeLast();
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

  String? _originBackDestination(String location) {
    final uri = Uri.tryParse(location);
    final from = uri?.queryParameters['from'];
    return switch (from) {
      'dashboard' => '/dashboard',
      'monitoramento' => '/monitoramento',
      _ => null,
    };
  }

  void _removeDestinationFromHistory(String destination) {
    final index = _previousLocations.lastIndexWhere((location) {
      return (Uri.tryParse(location)?.path ?? location) == destination;
    });
    if (index >= 0) {
      _previousLocations.removeRange(index, _previousLocations.length);
    }
  }
}

/// Receives Android's native back event before GoRouter tries to pop routes.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher(this._navigation);

  final AppBackNavigation _navigation;
  bool _handlingPredictiveBackGesture = false;

  @override
  Future<bool> didPopRoute() async {
    if (_navigation.handleSystemBack()) return true;
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
      _navigation.handleSystemBack();
    }
    _handlingPredictiveBackGesture = false;
  }

  @override
  void handleCancelBackGesture() {
    _handlingPredictiveBackGesture = false;
  }
}
