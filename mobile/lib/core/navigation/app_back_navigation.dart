import 'package:go_router/go_router.dart';
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

  bool handleSystemBack() {
    final router = _router;
    if (router == null || _previousLocations.isEmpty) return false;

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
}

/// Receives Android's native back event before GoRouter tries to pop routes.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher(this._navigation);

  final AppBackNavigation _navigation;

  @override
  Future<bool> didPopRoute() async {
    if (_navigation.handleSystemBack()) return true;
    return super.didPopRoute();
  }
}
