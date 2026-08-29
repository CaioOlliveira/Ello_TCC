import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import '../core/api/api_client.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/notifications/push_notification_service.dart';
import '../features/chat/application/chat_inbox_controller.dart';
import '../features/agenda/presentation/agenda_page.dart';
import '../features/alimentacao/presentation/alimentacao_page.dart';
import '../features/autenticacao/presentation/login_page.dart';
import '../features/chat/presentation/familia_chat_page.dart';
import '../features/coraia/presentation/coraia_page.dart';
import '../features/equipamentos/presentation/equipamentos_page.dart';
import '../features/equipamentos/presentation/equipamentos_history_page.dart';
import '../features/glicemia/presentation/glicemia_page.dart';
import '../features/historico/presentation/historico_page.dart';
import '../features/humor/presentation/humor_page.dart';
import '../features/idosos/presentation/adicionar_ficha_page.dart';
import '../features/idosos/presentation/cadastro_idoso_page.dart';
import '../features/idosos/presentation/dashboard_idoso_page.dart';
import '../features/idosos/presentation/perfil_idoso_page.dart';
import '../features/idosos/presentation/selecionar_idoso_page.dart';
import '../features/insumos/presentation/insumos_page.dart';
import '../features/ia/presentation/corgia_page.dart';
import '../features/oxigenacao/presentation/oxigenacao_page.dart';
import '../features/medicamentos/presentation/medicamentos_page.dart';
import '../features/monitoramento/presentation/monitoramento_page.dart';
import '../features/perfil/presentation/perfil_page.dart';
import '../features/permissoes/presentation/acessos_ficha_page.dart';
import '../features/permissoes/presentation/permissoes_detalhadas_page.dart';
import '../features/permissoes/presentation/permissoes_fichas_page.dart';
import '../features/pressao/presentation/pressao_page.dart';
import '../features/relatorios/presentation/relatorios_page.dart';
import '../features/splash/presentation/splash_page.dart';
import '../features/temperatura/presentation/temperatura_page.dart';

String? _moduleIdFromHistorico(String tipo) {
  return switch (tipo.toLowerCase()) {
    'agenda' => 'Agenda',
    'alimentacao' => 'Alimentacao',
    'equipamentos' => 'Equipamentos',
    'glicemia' => 'Glicemia',
    'humor' => 'Humor',
    'insumos' => 'Insumos',
    'medicamentos' || 'medicacoes' || 'remedios' => 'Medicacoes',
    'oxigenacao' => 'Oxigenacao',
    'pressao' => 'Pressao',
    'temperatura' => 'Temperatura',
    _ => null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/agenda',
        builder: (context, state) => const _ModuleAccessGate(
          moduleId: 'Agenda',
          child: AgendaPage(),
        ),
      ),
      GoRoute(
        path: '/agenda/historico',
        builder: (context, state) => const _ModuleAccessGate(
          moduleId: 'Agenda',
          child: HistoricoPage(tipo: 'agenda'),
        ),
      ),
      GoRoute(
        path: '/equipamentos',
        builder: (context, state) => const _ModuleAccessGate(
          moduleId: 'Equipamentos',
          child: EquipamentosPage(),
        ),
        routes: [
          GoRoute(
            path: 'historico',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Equipamentos',
              child: EquipamentosHistoryPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/idosos',
        builder: (context, state) => const SelecionarIdosoPage(),
      ),
      GoRoute(
        path: '/idosos/convite',
        builder: (context, state) => const ConviteIdosoPage(),
      ),
      GoRoute(
        path: '/idosos/adicionar',
        builder: (context, state) => const AdicionarFichaPage(),
      ),
      GoRoute(
        path: '/idosos/cadastro',
        builder: (context, state) => CadastroIdosoPage(
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/idosos/editar',
        builder: (context, state) => CadastroIdosoPage(
          edicao: true,
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(path: '/perfil', builder: (context, state) => const PerfilPage()),
      GoRoute(
        path: '/perfil/editar',
        builder: (context, state) => const EditarPerfilPage(),
      ),
      GoRoute(
        path: '/perfil/seguranca',
        builder: (context, state) => const SegurancaPerfilPage(),
      ),
      GoRoute(
        path: '/perfil/sobre',
        builder: (context, state) => const SobreAppPage(),
      ),
      GoRoute(
        path: '/permissoes',
        builder: (context, state) => const PermissoesFichasPage(),
      ),
      GoRoute(
        path: '/permissoes/detalhes',
        builder: (context, state) => PermissoesDetalhadasPage(
          membroId: state.uri.queryParameters['membroId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/idoso/acessos',
        builder: (context, state) => AcessosFichaPage(
          idosoId: state.uri.queryParameters['idosoId'],
        ),
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
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Glicemia',
              child: GlicemiaPage(),
            ),
          ),
          GoRoute(
            path: '/monitoramento',
            builder: (context, state) => const MonitoramentoPage(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const FamiliaChatPage(),
          ),
          GoRoute(
            path: '/chat/:peerId',
            builder: (context, state) {
              final extra = state.extra;
              final query = state.uri.queryParameters;
              return FamiliaChatDetailPage(
                peerId: state.pathParameters['peerId'] ?? '',
                initialPeer: extra is FamiliaChatPeer
                    ? extra
                    : FamiliaChatPeer(
                        id: state.pathParameters['peerId'] ?? '',
                        name: query['nome'] ?? 'Contato',
                        role: query['funcao'] ?? 'cuidador',
                      ),
              );
            },
          ),
          GoRoute(
            path: '/corgia',
            builder: (context, state) => const CorgiaPage(),
          ),
          GoRoute(
            path: '/alimentacao',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Alimentacao',
              child: AlimentacaoPage(),
            ),
          ),
          GoRoute(
            path: '/medicamentos',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Medicacoes',
              child: MedicamentosPage(),
            ),
          ),
          GoRoute(
              path: '/insumos',
              builder: (context, state) => const _ModuleAccessGate(
                    moduleId: 'Insumos',
                    child: InsumosPage(),
                  )),
          GoRoute(
            path: '/relatorios',
            builder: (context, state) => const RelatoriosPage(),
          ),
          GoRoute(
            path: '/humor',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Humor',
              child: HumorPage(),
            ),
          ),
          GoRoute(
            path: '/historico/:tipo',
            builder: (context, state) {
              final tipo = state.pathParameters['tipo'] ?? 'insumos';
              final moduleId = _moduleIdFromHistorico(tipo);
              final page = tipo.toLowerCase() == 'equipamentos'
                  ? const EquipamentosHistoryPage()
                  : HistoricoPage(tipo: tipo);
              return moduleId == null
                  ? page
                  : _ModuleAccessGate(moduleId: moduleId, child: page);
            },
          ),
          GoRoute(
            path: '/coraia',
            builder: (context, state) => const CoraIAPage(),
          ),
          GoRoute(
            path: '/pressao',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Pressao',
              child: PressaoPage(),
            ),
          ),
          GoRoute(
            path: '/oxigenacao',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Oxigenacao',
              child: OxigenacaoPage(),
            ),
          ),
          GoRoute(
            path: '/temperatura',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Temperatura',
              child: TemperaturaPage(),
            ),
          ),
          GoRoute(
            path: '/idoso/perfil',
            builder: (context, state) => const _ModuleAccessGate(
              moduleId: 'Ficha',
              child: PerfilIdosoPage(),
            ),
          ),
        ],
      ),
    ],
  );
});

class _ModuleAccessGate extends ConsumerWidget {
  const _ModuleAccessGate({
    required this.moduleId,
    required this.child,
  });

  final String moduleId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idoso = ref.watch(selectedIdosoProvider);

    if (idoso == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_search_rounded,
                    color: Color(0xFF147D8C),
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Selecione uma ficha para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/idosos'),
                    child: const Text('Escolher ficha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (idoso.podeVisualizarModulo(moduleId)) return child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF147D8C),
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acesso não liberado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Peça para o responsável liberar esta funcionalidade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF65757C)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/monitoramento'),
                  child: const Text('Voltar ao monitoramento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _localNotificationSubscription;
  StreamSubscription<ChatPushPayload>? _pushOpenedSubscription;
  StreamSubscription<ChatPushPayload>? _pushForegroundSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localNotificationSubscription = LocalNotificationService.instance.responses
        .listen(_openChatFromPayload);
    _pushOpenedSubscription = PushNotificationService.instance.openedMessages
        .listen(_openChatFromPush);
    _pushForegroundSubscription =
        PushNotificationService.instance.foregroundMessages.listen((payload) {
      ref.read(chatInboxProvider.notifier).notifyIncomingMessage(
            ChatIncomingMessage(
              idosoId: payload.idosoId,
              peerId: payload.peerId,
              messageId: payload.messageId,
            ),
          );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = LocalNotificationService.instance.takeLaunchPayload();
      if (payload != null) _openChatFromPayload(payload);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localNotificationSubscription?.cancel();
    _pushOpenedSubscription?.cancel();
    _pushForegroundSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(chatInboxProvider.notifier).setAppActive(
          state != AppLifecycleState.paused &&
              state != AppLifecycleState.detached,
        );
  }

  Future<void> _openChatFromPayload(String payload) async {
    final parts = payload.split(':');
    if (parts.length != 3 || parts.first != 'chat') return;
    await _openChatFromNotification(parts[1], parts[2]);
  }

  Future<void> _openChatFromPush(ChatPushPayload payload) {
    return _openChatFromNotification(payload.idosoId, payload.peerId);
  }

  Future<void> _openChatFromNotification(
    String idosoId,
    String peerId,
  ) async {
    final usuario = ref.read(authSessionProvider);
    if (usuario == null ||
        usuario.id.isEmpty ||
        idosoId.isEmpty ||
        peerId.isEmpty) {
      return;
    }

    final selected = ref.read(selectedIdosoProvider);
    if (selected?.id != idosoId) {
      try {
        final idosos = await ref
            .read(apiClientProvider)
            .listarIdosos(usuarioId: usuario.id);
        IdosoResumo? idoso;
        for (final item in idosos) {
          if (item.id == idosoId) {
            idoso = item;
            break;
          }
        }
        if (idoso == null) return;
        ref.read(selectedIdosoProvider.notifier).state = idoso;
      } catch (_) {
        return;
      }
    }

    if (!mounted) return;
    context.go('/chat/${Uri.encodeComponent(peerId)}');
  }

  int _currentIndex(String location) {
    if (location == '/monitoramento' ||
        location == '/agenda' ||
        location == '/glicemia' ||
        location == '/alimentacao' ||
        location == '/medicamentos' ||
        location == '/equipamentos' ||
        location == '/insumos' ||
        location == '/humor' ||
        location.startsWith('/historico/') ||
        location == '/pressao' ||
        location == '/oxigenacao' ||
        location == '/temperatura') {
      return 1;
    }
    if (location == '/chat' || location.startsWith('/chat/')) return 2;
    if (location == '/relatorios') return 3;
    if (location == '/idoso/perfil') return 3;
    return 0;
  }

  void _configureChat({
    required String? usuarioId,
    required String? idosoId,
    required String? accessToken,
  }) {
    ref.read(chatInboxProvider.notifier).configure(
          usuarioId: usuarioId,
          idosoId: idosoId,
          accessToken: accessToken,
        );
    unawaited(
      PushNotificationService.instance.configure(
        api: ref.read(apiClientProvider),
        usuarioId: usuarioId,
        accessToken: accessToken,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final usuario = ref.watch(authSessionProvider);
    final idoso = ref.watch(selectedIdosoProvider);
    final selectedIndex = _currentIndex(location);
    final hideBottomNav = location == '/agenda' ||
        location == '/agenda/historico' ||
        location == '/equipamentos' ||
        location == '/equipamentos/historico' ||
        location == '/alimentacao' ||
        location == '/insumos' ||
        location == '/humor' ||
        location == '/corgia' ||
        location == '/coraia' ||
        location.startsWith('/chat/') ||
        location.startsWith('/historico/');
    final showCoraFab =
        location == '/dashboard' || location == '/monitoramento';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _configureChat(
        usuarioId: usuario?.id,
        idosoId: idoso?.id,
        accessToken: usuario?.accessToken,
      );
    });

    return Scaffold(
      body: widget.child,
      floatingActionButton: showCoraFab
          ? _CoraFloatingButton(onTap: () => context.go('/corgia'))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: hideBottomNav
          ? null
          : SafeArea(
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
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                      onTap: () => context.go('/chat'),
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

class _CoraFloatingButton extends StatelessWidget {
  const _CoraFloatingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 76, right: 2),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 7,
        shadowColor: const Color(0xFF0E6F7E).withValues(alpha: 0.35),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9BDDE8), width: 1.5),
            ),
            child: Image.asset(
              'assets/images/cora_avatar.png',
              fit: BoxFit.contain,
            ),
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
