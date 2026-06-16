import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_card.dart';

class SelecionarIdosoPage extends StatelessWidget {
  const SelecionarIdosoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar idoso')),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: AppCard(
          title: AppStrings.elderName,
          description: '${AppStrings.elderAge} - ${AppStrings.elderConditions}',
          icon: Icons.elderly_outlined,
          onTap: () => context.go('/dashboard'),
        ),
      ),
    );
  }
}
