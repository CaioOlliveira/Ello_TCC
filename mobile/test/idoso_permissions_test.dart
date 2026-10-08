import 'package:flutter_test/flutter_test.dart';

import 'package:ello_mobile/core/api/api_client.dart';
import 'package:ello_mobile/features/monitoramento/presentation/monitoramento_catalog.dart';

void main() {
  test('todos os monitoramentos começam selecionados no cadastro', () {
    expect(defaultMonitoramentoIds, hasLength(monitoramentoOptions.length));
    expect(
        defaultMonitoramentoIds,
        containsAll([
          'Pressao',
          'Oxigenacao',
          'Temperatura',
        ]));
  });

  test('gastos não aparece para cuidador nem administrador', () {
    const idoso = IdosoResumo(
      id: 'idoso-1',
      nome: 'Maria Aparecida',
      idade: 78,
      condicoes: [],
      monitoramentos: ['Gastos', 'Alimentacao'],
      permissoesVisualizar: ['Gastos', 'Alimentacao'],
    );
    final administrador = idoso.copyWith(eAdministrador: true);

    expect(idoso.monitoramentosVisiveis, ['Alimentacao']);
    expect(administrador.monitoramentosVisiveis, ['Alimentacao']);
  });

  test('gastos continua disponível para o responsável', () {
    const idoso = IdosoResumo(
      id: 'idoso-1',
      nome: 'Maria Aparecida',
      idade: 78,
      condicoes: [],
      ehDono: true,
      monitoramentos: ['Gastos', 'Alimentacao'],
    );

    expect(idoso.monitoramentosVisiveis, ['Gastos', 'Alimentacao']);
  });
}
