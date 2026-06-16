import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_sizes.dart';
import 'app_button.dart';
import 'empty_state.dart';

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        title: title,
        message: 'Este modulo sera implementado nas proximas etapas.',
        action: AppButton(
          label: canPop ? 'Voltar' : 'Inicio',
          icon: canPop ? Icons.arrow_back : Icons.home_outlined,
          onPressed: () {
            if (canPop) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const SizedBox(height: AppSizes.xs),
    );
  }
}
