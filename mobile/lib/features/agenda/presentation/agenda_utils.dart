import 'package:flutter/material.dart';

const agendaBaseTags = ['Consulta', 'Exame', 'Evento social'];

bool sameAgendaDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

int? dayForCalendarCell(int row, int column, int leading, int daysInMonth) {
  final value = (row * 7) + column - leading + 1;
  if (value < 1 || value > daysInMonth) return null;
  return value;
}

String formatAgendaDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String formatAgendaIsoDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatAgendaTime(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String formatAgendaTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String agendaWeekdayShort(int weekday) {
  const names = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'];
  return names[weekday - 1];
}

String agendaMonthName(int month) {
  const names = [
    'Janeiro',
    'Fevereiro',
    'Marco',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return names[month - 1];
}

Color agendaTagColor(String tag) {
  final normalized = tag.toLowerCase();
  if (normalized.contains('consulta')) return const Color(0xFFFF8AA8);
  if (normalized.contains('exame')) return const Color(0xFFFFD977);
  if (normalized.contains('social')) return const Color(0xFF66D7E7);
  if (normalized.contains('fisio') || normalized.contains('exercicio')) {
    return const Color(0xFFFFD977);
  }
  return const Color(0xFFBFE9F1);
}
