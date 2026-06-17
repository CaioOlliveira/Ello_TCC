import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SelecionarIdosoPage extends StatelessWidget {
  const SelecionarIdosoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.go('/login'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF238FA1),
                                size: 32,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Sair',
                                style: TextStyle(
                                  color: Color(0xFF1D2528),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'ello',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF0E6F7E),
                        fontSize: 47,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Crie sua primeira\nficha!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF2CA0B4),
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Escolha como deseja adicionar uma nova ficha\nao seu acompanhamento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7D7D7D),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 38),
                _FichaOptionCard(
                  icon: Icons.link_rounded,
                  iconBackground: const Color(0xFFBDEAF1),
                  iconColor: const Color(0xFF2396AA),
                  title: 'Entrar em uma\nficha compartilhada',
                  description:
                      'Use o código ou convite\nenviado por outro cuidador\npara acessar uma ficha já\nexistente',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Código de convite',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          style: const TextStyle(
                            color: Color(0xFF17324D),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Digite o código aqui',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9B9B9B),
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide: const BorderSide(
                                color: Color(0xFF9DA3A6),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide: const BorderSide(
                                color: Color(0xFF9DA3A6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SmallFilledButton(
                        label: 'Acessar ficha',
                        color: const Color(0xFF3CB1C3),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Entrada por convite será liberada em breve.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _FichaOptionCard(
                  icon: Icons.person_add_alt_1_outlined,
                  iconBackground: const Color(0xFFACDDE7),
                  iconColor: const Color(0xFF17324D),
                  title: 'Criar nova ficha',
                  description:
                      'Cadastre um novo idoso e\ncrie uma ficha completa para\nacompanhamento',
                  child: _SmallFilledButton(
                    label: 'Criar ficha',
                    color: const Color(0xFF1E5D73),
                    onPressed: () => context.go('/idosos/cadastro'),
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

class _FichaOptionCard extends StatelessWidget {
  const _FichaOptionCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E1E1)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 29),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2CA0B4),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF515151),
                        fontSize: 14,
                        height: 1.23,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SmallFilledButton extends StatelessWidget {
  const _SmallFilledButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(label),
      ),
    );
  }
}
