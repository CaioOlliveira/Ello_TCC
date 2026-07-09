import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'app_button.dart';
import 'staggered_entry.dart';

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({required this.title, super.key});

  final String title;

  IconData get _icon {
    final normalized = title.toLowerCase();
    if (normalized.contains('agua')) return Icons.local_drink_rounded;
    if (normalized.contains('press')) return Icons.speed_rounded;
    if (normalized.contains('oxig')) return Icons.air_rounded;
    if (normalized.contains('sono')) return Icons.bedtime_rounded;
    if (normalized.contains('aliment')) return Icons.restaurant_rounded;
    if (normalized.contains('medicament')) {
      return Icons.medication_rounded;
    }
    if (normalized.contains('relat')) return Icons.bar_chart_rounded;
    if (normalized.contains('perfil')) return Icons.person_rounded;
    return Icons.dashboard_customize_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggeredEntry(
                    index: 0,
                    child: InkWell(
                      onTap: () {
                        if (canPop) {
                          context.pop();
                        } else {
                          context.go('/dashboard');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF2A9CAE),
                              size: 28,
                            ),
                            Text(
                              'Voltar',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StaggeredEntry(
                              index: 1,
                              child: _BreathingIcon(icon: _icon),
                            ),
                            const SizedBox(height: AppSizes.lg),
                            StaggeredEntry(
                              index: 2,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF073248),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            StaggeredEntry(
                              index: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Em breve',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.md),
                            const StaggeredEntry(
                              index: 4,
                              child: Text(
                                'Este modulo sera implementado nas proximas etapas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF607178),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.xl),
                            StaggeredEntry(
                              index: 5,
                              child: AppButton(
                                label: canPop ? 'Voltar' : 'Inicio',
                                icon: canPop
                                    ? Icons.arrow_back
                                    : Icons.home_outlined,
                                onPressed: () {
                                  if (canPop) {
                                    context.pop();
                                  } else {
                                    context.go('/dashboard');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon({required this.icon});

  final IconData icon;

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: AppColors.primary, size: 54),
      ),
    );
  }
}
