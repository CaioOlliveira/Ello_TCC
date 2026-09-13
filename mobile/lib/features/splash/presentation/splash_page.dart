import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_palette.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _restaurarSessaoENavegar();
  }

  Future<void> _restaurarSessaoENavegar() async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(const Duration(milliseconds: 1100)),
      ref.read(sessaoUsuarioLocalProvider).carregar(),
    ]);
    if (!mounted) return;

    final usuario = results[1] as UsuarioSessao?;
    if (usuario != null) {
      ref.read(authSessionProvider.notifier).state = usuario;
      await _restoreLastNavigation(usuario);
      return;
    }

    context.go('/login');
  }

  Future<void> _restoreLastNavigation(UsuarioSessao usuario) async {
    final saved = await ref.read(appNavigationStateLocalProvider).carregar();
    if (!mounted) return;

    if (saved == null || saved.idosoId == null || saved.idosoId!.isEmpty) {
      context.go('/idosos');
      return;
    }

    try {
      final idosos =
          await ref.read(apiClientProvider).listarIdosos(usuarioId: usuario.id);
      if (!mounted) return;

      IdosoResumo? selected;
      for (final idoso in idosos) {
        if (idoso.id == saved.idosoId) {
          selected = idoso;
          break;
        }
      }

      if (selected == null) {
        context.go('/idosos');
        return;
      }

      ref.read(selectedIdosoProvider.notifier).state = selected;
      context.go(saved.location);
    } catch (_) {
      if (mounted) context.go('/idosos');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, AppColors.background, AppDarkColors.bg),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF3396A8),
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  'ello',
                  style: TextStyle(
                    color: Color(0xFF0E6F7E),
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
