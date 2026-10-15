import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/navigation/app_back_navigation.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/notifications/push_notification_service.dart';
import 'providers.dart';
import 'router.dart';

class ElloApp extends ConsumerStatefulWidget {
  const ElloApp({super.key});

  static final _backButtonDispatcher =
      AppBackButtonDispatcher(AppBackNavigation.instance);

  @override
  ConsumerState<ElloApp> createState() => _ElloAppState();
}

class _ElloAppState extends ConsumerState<ElloApp> {
  late final GoRouter _router;
  StreamSubscription<AccessRequestPushPayload>? _openedAccess;
  StreamSubscription<AccessRequestPushPayload>? _foregroundAccess;
  StreamSubscription<String>? _localResponses;
  String? _pendingAccess;
  String? _configuredSession;
  bool _openingAccess = false;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _router.routeInformationProvider.addListener(_retryPendingAccess);
    _openedAccess = PushNotificationService.instance.openedAccessRequests
        .listen((payload) => _openAccess(payload.localPayload));
    _foregroundAccess = PushNotificationService
        .instance.foregroundAccessRequests
        .listen((payload) {
      unawaited(LocalNotificationService.instance.showNow(
        id: stableNotificationId('access:${payload.requestId}'),
        title: payload.title,
        body: payload.body,
        payload: payload.localPayload,
      ));
    });
    _localResponses = LocalNotificationService.instance.responses.listen(
      (payload) {
        if (payload.startsWith('access:')) _openAccess(payload);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = LocalNotificationService.instance.takeLaunchPayloadWhere(
        (value) => value.startsWith('access:'),
      );
      if (payload != null) _openAccess(payload);
    });
  }

  void _retryPendingAccess() {
    final payload = _pendingAccess;
    if (payload != null) unawaited(_openAccess(payload));
  }

  Future<void> _openAccess(String payload) async {
    final parts = payload.split(':');
    if (parts.length != 3 || parts.first != 'access' || _openingAccess) return;
    final session = ref.read(authSessionProvider);
    final router = ref.read(routerProvider);
    final path = router.routeInformationProvider.value.uri.path;
    if (session == null || path == '/' || path == '/login') {
      _pendingAccess = payload;
      return;
    }
    _pendingAccess = null;
    _openingAccess = true;
    try {
      final fichas = await ref.read(apiClientProvider).listarIdosos(
            usuarioId: session.id,
            forceRefresh: true,
          );
      if (!mounted || ref.read(authSessionProvider)?.id != session.id) return;
      final ficha = fichas.where((item) => item.id == parts[1]).firstOrNull;
      if (ficha == null || !ficha.temAcessoTotal) return;
      ref.read(selectedIdosoProvider.notifier).state = ficha;
      router.go(Uri(path: '/idoso/acessos', queryParameters: {
        'idosoId': parts[1],
        'solicitacaoId': parts[2],
      }).toString());
    } catch (_) {
      // A tela permanece acessível pelo menu caso a rede falhe.
    } finally {
      _openingAccess = false;
    }
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_retryPendingAccess);
    _openedAccess?.cancel();
    _foregroundAccess?.cancel();
    _localResponses?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final session = ref.watch(authSessionProvider);
    final sessionKey = '${session?.id}|${session?.accessToken}';
    if (session != null && _configuredSession != sessionKey) {
      _configuredSession = sessionKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(PushNotificationService.instance.configure(
          api: ref.read(apiClientProvider),
          usuarioId: session.id,
          accessToken: session.accessToken,
        ));
        _retryPendingAccess();
      });
    }
    AppBackNavigation.instance.attach(router);

    return MaterialApp.router(
      title: 'Ello',
      restorationScopeId: 'ello_app',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: ElloApp._backButtonDispatcher,
      onNavigationNotification: (notification) {
        // Routes navigated with GoRouter.go replace the Navigator stack. Keep
        // Android's predictive-back gesture enabled while our route history
        // still has a screen to return to, otherwise Android closes the app
        // before Flutter receives the gesture.
        SystemNavigator.setFrameworkHandlesBack(
          notification.canHandlePop ||
              AppBackNavigation.instance.canHandleSystemBack,
        );
        return true;
      },
    );
  }
}
