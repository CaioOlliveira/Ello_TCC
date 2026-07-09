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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _AppNavBar(
            selectedIndex: selectedIndex,
            items: [
              _NavItemData(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Início',
                onTap: () => context.go('/dashboard'),
              ),
              _NavItemData(
                icon: Icons.monitor_heart_outlined,
                activeIcon: Icons.monitor_heart_rounded,
                label: 'Monitorar',
                onTap: () => context.go('/monitoramento'),
              ),
              _NavItemData(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome_rounded,
                label: 'CoraIA',
                onTap: () => context.go('/corgia'),
              ),
              _NavItemData(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Perfil',
                onTap: () => context.go('/idoso/perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
}

class _AppNavBar extends StatelessWidget {
  const _AppNavBar({required this.selectedIndex, required this.items});

  final int selectedIndex;
  final List<_NavItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003B4F), Color(0xFF0E6F7E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E6F7E).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / items.length;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: slotWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: slotWidth,
                child: Center(
                  child: Container(
                    width: slotWidth - 8,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: slotWidth,
                      child: _NavItem(
                        data: items[i],
                        selected: i == selectedIndex,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.selected});

  final _NavItemData data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0E6F7E) : Colors.white;

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: selected ? 1 : 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 1 + value * 0.15,
                child: Icon(
                  selected ? data.activeIcon : data.icon,
                  color: color,
                  size: 23,
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: selected ? 11 : 0,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            child: Text(data.label, maxLines: 1, overflow: TextOverflow.clip),
          ),
        ],
      ),
    );
  }
}
