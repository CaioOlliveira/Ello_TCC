import 'package:flutter/material.dart';

class MonitoramentoOption {
  const MonitoramentoOption({
    required this.id,
    required this.title,
    required this.selectionLabel,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String id;
  final String title;
  final String selectionLabel;
  final String subtitle;
  final IconData icon;
  final String route;
}

const defaultMonitoramentoIds = [
  'Medicacoes',
  'Humor',
  'Agenda',
  'Alimentacao',
  'Equipamentos',
  'Insumos',
  'Glicemia',
];

const monitoramentoOptions = [
  MonitoramentoOption(
    id: 'Medicacoes',
    title: 'Remédios',
    selectionLabel: 'Medicações',
    subtitle: 'Registro e controle',
    icon: Icons.medication_rounded,
    route: '/medicamentos',
  ),
  MonitoramentoOption(
    id: 'Humor',
    title: 'Humor',
    selectionLabel: 'Humor',
    subtitle: 'Emoções e observações',
    icon: Icons.mood_rounded,
    route: '/humor',
  ),
  MonitoramentoOption(
    id: 'Agenda',
    title: 'Agenda',
    selectionLabel: 'Agenda',
    subtitle: 'Compromissos',
    icon: Icons.calendar_month_rounded,
    route: '/agenda',
  ),
  MonitoramentoOption(
    id: 'Alimentacao',
    title: 'Alimentação',
    selectionLabel: 'Alimentação',
    subtitle: 'Refeições do dia',
    icon: Icons.restaurant_rounded,
    route: '/alimentacao',
  ),
  MonitoramentoOption(
    id: 'Equipamentos',
    title: 'Equipamentos',
    selectionLabel: 'Equipamentos',
    subtitle: 'Manutenção e uso',
    icon: Icons.accessible_forward_rounded,
    route: '/equipamentos',
  ),
  MonitoramentoOption(
    id: 'Insumos',
    title: 'Insumos',
    selectionLabel: 'Insumos',
    subtitle: 'Estoque de produtos',
    icon: Icons.inventory_2_rounded,
    route: '/insumos',
  ),
  MonitoramentoOption(
    id: 'Glicemia',
    title: 'Glicemia',
    selectionLabel: 'Glicemia',
    subtitle: 'Histórico de glicemia',
    icon: Icons.water_drop_rounded,
    route: '/glicemia',
  ),
  MonitoramentoOption(
    id: 'Pressao',
    title: 'Pressão',
    selectionLabel: 'Pressão arterial',
    subtitle: 'Histórico de pressão',
    icon: Icons.favorite_rounded,
    route: '/pressao',
  ),
  MonitoramentoOption(
    id: 'Oxigenacao',
    title: 'Oxigenação',
    selectionLabel: 'Oxigenação',
    subtitle: 'Saturação de oxigênio',
    icon: Icons.air_rounded,
    route: '/oxigenacao',
  ),
  MonitoramentoOption(
    id: 'Temperatura',
    title: 'Temperatura',
    selectionLabel: 'Temperatura',
    subtitle: 'Histórico de temperatura',
    icon: Icons.thermostat_rounded,
    route: '/temperatura',
  ),
];

List<MonitoramentoOption> monitoramentoOptionsByIds(Iterable<String> ids) {
  final selectedIds = ids.toSet();
  return [
    for (final option in monitoramentoOptions)
      if (selectedIds.contains(option.id)) option,
  ];
}
