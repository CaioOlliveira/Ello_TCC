import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_card.dart';

class DashboardIdosoPage extends StatelessWidget {
  const DashboardIdosoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      _DashboardItem('Glicemia', 'Registrar medicoes de glicose.',
          Icons.bloodtype_outlined, '/glicemia'),
      _DashboardItem('Alimentacao', 'Acompanhar refeicoes.',
          Icons.restaurant_outlined, '/alimentacao'),
      _DashboardItem('Medicamentos', 'Controlar medicamentos.',
          Icons.medication_outlined, '/medicamentos'),
      _DashboardItem('Agenda', 'Ver compromissos e rotinas.',
          Icons.event_outlined, '/agenda'),
      _DashboardItem('Equipamentos', 'Acompanhar equipamentos.',
          Icons.medical_services_outlined, '/equipamentos'),
      _DashboardItem('Insumos', 'Controlar estoque de insumos.',
          Icons.inventory_2_outlined, '/insumos'),
      _DashboardItem('Relatorios', 'Consultar resumos do cuidado.',
          Icons.bar_chart_outlined, '/relatorios'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Text(AppStrings.elderName,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSizes.xs),
          const Text('${AppStrings.elderAge} - ${AppStrings.elderConditions}'),
          const SizedBox(height: AppSizes.lg),
          for (final item in items)
            AppCard(
              title: item.title,
              description: item.description,
              icon: item.icon,
              onTap: () => context.go(item.route),
            ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem(this.title, this.description, this.icon, this.route);

  final String title;
  final String description;
  final IconData icon;
  final String route;
}
