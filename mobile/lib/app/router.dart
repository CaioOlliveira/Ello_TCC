import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agenda/presentation/agenda_page.dart';
import '../features/alimentacao/presentation/alimentacao_page.dart';
import '../features/autenticacao/presentation/login_page.dart';
import '../features/equipamentos/presentation/equipamentos_page.dart';
import '../features/glicemia/presentation/glicemia_page.dart';
import '../features/humor/presentation/humor_page.dart';
import '../features/idosos/presentation/cadastro_idoso_page.dart';
import '../features/idosos/presentation/dashboard_idoso_page.dart';
import '../features/idosos/presentation/selecionar_idoso_page.dart';
import '../features/insumos/presentation/insumos_page.dart';
import '../features/ia/presentation/corgia_page.dart';
import '../features/medicamentos/presentation/medicamentos_page.dart';
import '../features/monitoramento/presentation/monitoramento_page.dart';
import '../features/perfil/presentation/perfil_page.dart';
import '../features/relatorios/presentation/relatorios_page.dart';
import '../features/splash/presentation/splash_page.dart';
import '../shared/widgets/module_placeholder_page.dart';

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
        path: '/idosos/convite',
        builder: (context, state) => const ConviteIdosoPage(),
      ),
      GoRoute(
        path: '/idosos/cadastro',
        builder: (context, state) => const CadastroIdosoPage(),
      ),
      GoRoute(path: '/perfil', builder: (context, state) => const PerfilPage()),
      GoRoute(
        path: '/perfil/editar',
        builder: (context, state) => const EditarPerfilPage(),
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
            path: '/monitoramento',
            builder: (context, state) => const MonitoramentoPage(),
          ),
          GoRoute(
            path: '/corgia',
            builder: (context, state) => const CorgiaPage(),
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
            path: '/humor',
            builder: (context, state) => const HumorPage(),
          ),
          GoRoute(
            path: '/agua',
            builder: (context, state) =>
                const ModulePlaceholderPage(title: 'Agua'),
          ),
          GoRoute(
            path: '/pressao',
            builder: (context, state) =>
                const ModulePlaceholderPage(title: 'Pressao arterial'),
          ),
          GoRoute(
            path: '/oxigenacao',
            builder: (context, state) =>
                const ModulePlaceholderPage(title: 'Oxigenacao'),
          ),
          GoRoute(
            path: '/sono',
            builder: (context, state) =>
                const ModulePlaceholderPage(title: 'Sono'),
          ),
          GoRoute(
            path: '/idoso/perfil',
            builder: (context, state) =>
                const ModulePlaceholderPage(title: 'Perfil do idoso'),
          ),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _currentIndex(String location) {
    if (location == '/monitoramento' ||
        location == '/agenda' ||
        location == '/glicemia' ||
        location == '/alimentacao' ||
        location == '/medicamentos' ||
        location == '/equipamentos' ||
        location == '/insumos' ||
        location == '/humor' ||
        location == '/agua' ||
        location == '/pressao' ||
        location == '/oxigenacao' ||
        location == '/sono') {
      return 1;
    }
    if (location == '/corgia') return 2;
    if (location == '/relatorios') return 3;
    if (location == '/idoso/perfil') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF003B4F),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ShellNavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => context.go('/dashboard'),
                ),
                _ShellNavItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Monitoramento',
                  selected: selectedIndex == 1,
                  onTap: () => context.go('/monitoramento'),
                ),
                _ShellNavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'CoraIA',
                  selected: selectedIndex == 2,
                  onTap: () => context.go('/corgia'),
                ),
                _ShellNavItem(
                  icon: Icons.person_outline,
                  label: 'Perfil',
                  selected: selectedIndex == 3,
                  onTap: () => context.go('/idoso/perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 33,
        padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF003B4F) : Colors.white,
              size: 21,
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF003B4F),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
