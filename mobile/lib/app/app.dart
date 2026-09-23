import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/navigation/app_back_navigation.dart';
import 'router.dart';

class ElloApp extends ConsumerWidget {
  const ElloApp({super.key});

  static final _backButtonDispatcher =
      AppBackButtonDispatcher(AppBackNavigation.instance);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
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
      backButtonDispatcher: _backButtonDispatcher,
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
