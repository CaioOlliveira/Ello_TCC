import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/staggered_entry.dart';

class AdicionarFichaPage extends StatelessWidget {
  const AdicionarFichaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          adaptive(context, const Color(0xFFFCFCFC), AppDarkColors.bg),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode(context)
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: 'Adicionar ficha',
                      onBack: () => context.go('/idosos'),
                    ),
                    const Spacer(),
                    StaggeredEntry(
                      index: 0,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2BA8BA), Color(0xFF0E6F7E)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StaggeredEntry(
                      index: 1,
                      child: Text(
                        'Qual é o seu papel?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: adaptive(
                            context,
                            const Color(0xFF17324D),
                            AppDarkColors.textPrimary,
                          ),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredEntry(
                      index: 2,
                      child: Text(
                        'Escolha como você deseja adicionar a ficha',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: adaptive(
                            context,
                            const Color(0xFF5C6B73),
                            AppDarkColors.textSecondary,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    StaggeredEntry(
                      index: 3,
                      child: _RoleCard(
                        icon: Icons.badge_outlined,
                        title: 'Sou o responsável',
                        description:
                            'Quero cadastrar e administrar uma nova ficha.',
                        onTap: () =>
                            context.go('/idosos/cadastro?from=adicionar'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    StaggeredEntry(
                      index: 4,
                      child: _RoleCard(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'Sou o cuidador',
                        description:
                            'Recebi um convite para acessar uma ficha.',
                        onTap: () => context.go('/idosos/convite'),
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adaptive(context, Colors.white, AppDarkColors.surface),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: adaptive(
                context,
                const Color(0xFFB9DFE5),
                AppDarkColors.borderStrong,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: adaptive(
                    context,
                    const Color(0xFFDDF3F6),
                    AppDarkColors.tintedInfo,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF16889A), size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: adaptive(
                          context,
                          const Color(0xFF17324D),
                          AppDarkColors.textPrimary,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: adaptive(
                          context,
                          const Color(0xFF5C6B73),
                          AppDarkColors.textSecondary,
                        ),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF16889A),
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
