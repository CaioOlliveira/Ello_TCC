import 'package:ello_mobile/core/navigation/app_back_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('gesto volta do formulário para agenda e depois para origem',
      (tester) async {
    final router = GoRouter(
      navigatorKey: AppBackNavigation.rootNavigatorKey,
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard')),
        ),
        GoRoute(
          path: '/agenda',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Cadastrar')),
                    ),
                  ),
                  child: const Text('Agenda'),
                ),
                TextButton(
                  onPressed: () => context.push('/agenda/historico'),
                  child: const Text('Histórico'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/agenda/historico',
          builder: (_, __) => const Scaffold(body: Text('Histórico da agenda')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    AppBackNavigation.instance.attach(router);

    router.go('/agenda');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar'), findsOneWidget);

    expect(await AppBackNavigation.instance.handleSystemBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Cadastrar'), findsNothing);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Histórico da agenda'), findsOneWidget);
    expect(await AppBackNavigation.instance.handleSystemBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsOneWidget);

    expect(await AppBackNavigation.instance.handleSystemBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('gesto fecha primeiro o formulário interno de um módulo',
      (tester) async {
    var editing = false;
    final router = GoRouter(
      navigatorKey: AppBackNavigation.rootNavigatorKey,
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard')),
        ),
        ShellRoute(
          navigatorKey: AppBackNavigation.shellNavigatorKey,
          builder: (_, __, child) => child,
          routes: [
            GoRoute(
              path: '/medicamentos',
              builder: (_, __) => StatefulBuilder(
                builder: (context, setState) => PopScope(
                  canPop: !editing,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) setState(() => editing = false);
                  },
                  child: Scaffold(
                    body: TextButton(
                      onPressed: () => setState(() => editing = true),
                      child: Text(editing ? 'Formulário' : 'Medicamentos'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    AppBackNavigation.instance.attach(router);

    router.go('/medicamentos');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Formulário'), findsOneWidget);

    expect(await AppBackNavigation.instance.handleSystemBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Medicamentos'), findsOneWidget);

    expect(await AppBackNavigation.instance.handleSystemBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
