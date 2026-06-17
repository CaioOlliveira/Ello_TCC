import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agenda/presentation/agenda_page.dart';
import '../features/alimentacao/presentation/alimentacao_page.dart';
import '../features/autenticacao/presentation/login_page.dart';
import '../features/equipamentos/presentation/equipamentos_page.dart';
import '../features/glicemia/presentation/glicemia_page.dart';
import '../features/idosos/presentation/cadastro_idoso_page.dart';
import '../features/idosos/presentation/dashboard_idoso_page.dart';
import '../features/idosos/presentation/selecionar_idoso_page.dart';
import '../features/insumos/presentation/insumos_page.dart';
import '../features/medicamentos/presentation/medicamentos_page.dart';
import '../features/perfil/presentation/perfil_page.dart';
import '../features/relatorios/presentation/relatorios_page.dart';
import '../features/splash/presentation/splash_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/idosos',
        builder: (context, state) => const SelecionarIdosoPage(),
      ),
      GoRoute(
        path: '/idosos/cadastro',
        builder: (context, state) => const CadastroIdosoPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardIdosoPage(),
          ),
          GoRoute(
            path: '/glicemia',
            builder: (context, state) => const GlicemiaPage(),
          ),
          GoRoute(
            path: '/alimentacao',
            builder: (context, state) => const AlimentacaoPage(),
          ),
          GoRoute(
            path: '/medicamentos',
            builder: (context, state) => const MedicamentosPage(),
          ),
          GoRoute(
              path: '/agenda', builder: (context, state) => const AgendaPage()),
          GoRoute(
            path: '/equipamentos',
            builder: (context, state) => const EquipamentosPage(),
          ),
          GoRoute(
              path: '/insumos',
              builder: (context, state) => const InsumosPage()),
          GoRoute(
            path: '/relatorios',
            builder: (context, state) => const RelatoriosPage(),
          ),
          GoRoute(
              path: '/perfil', builder: (context, state) => const PerfilPage()),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _currentIndex(String location) {
    if (location == '/agenda') return 1;
    if (location == '/glicemia' ||
        location == '/alimentacao' ||
        location == '/medicamentos' ||
        location == '/equipamentos' ||
        location == '/insumos') {
      return 2;
    }
    if (location == '/relatorios') return 3;
    if (location == '/perfil') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(location),
        onDestinationSelected: (index) {
          final routes = [
            '/dashboard',
            '/agenda',
            '/glicemia',
            '/relatorios',
            '/perfil'
          ];
          context.go(routes[index]);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined), label: 'Agenda'),
          NavigationDestination(
              icon: Icon(Icons.edit_note_outlined), label: 'Registros'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Relatorios'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
