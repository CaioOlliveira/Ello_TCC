import 'package:ello_mobile/core/api/api_client.dart';
import 'package:ello_mobile/features/gastos/presentation/gastos_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gera um PDF valido com o resumo de gastos', () async {
    final bytes = await buildGastosPdf(
      gastos: [
        GastoResumo(
          id: 'gasto-1',
          idosoId: 'idoso-1',
          valor: 123.45,
          descricao: 'Medicamentos',
          fonte: 'Farmácia',
          dataGasto: DateTime(2026, 9, 23),
          criadoPorId: 'usuario-1',
          criadoEm: DateTime(2026, 9, 23, 10, 30),
        ),
      ],
      total: 123.45,
      titulo: 'Gastos do dia',
      periodo: '23/09/2026',
      introducao: 'Relatório dos gastos registrados no dia.',
      nomeIdoso: 'Maria',
      geradoEm: DateTime(2026, 9, 23, 11),
    );

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('sem permissao de visualizacao nao exibe monitoramentos', () {
    const idoso = IdosoResumo(
      id: 'idoso-1',
      nome: 'Maria',
      idade: 80,
      condicoes: [],
      monitoramentos: ['Agenda', 'Medicacoes'],
      permissoesVisualizar: [],
      permissoesEditar: [],
    );

    expect(idoso.monitoramentosVisiveis, isEmpty);
  });
}
