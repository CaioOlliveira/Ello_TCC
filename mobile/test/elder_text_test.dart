import 'package:ello_mobile/core/utils/elder_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElderText', () {
    test('usa paciente no feminino', () {
      final text = ElderText.fromSexo('Feminino');
      expect(text.singular, 'paciente');
      expect(text.of, 'da paciente');
      expect(text.howFeeling(), 'Como a paciente está se sentindo?');
      expect(normalizeSexo('idosa'), 'Feminino');
    });
    test('usa paciente no masculino', () {
      final text = ElderText.fromSexo('M');
      expect(text.singular, 'paciente');
      expect(text.of, 'do paciente');
      expect(text.howFeeling(), 'Como o paciente está se sentindo?');
      expect(normalizeSexo('idoso'), 'Masculino');
    });
    test('usa paciente sem sexo definido', () {
      final text = ElderText.fromSexo(null);
      expect(text.singular, 'paciente');
      expect(text.selectedWithArticle, 'o paciente selecionado');
      expect(text.howFeeling(), 'Como o paciente está se sentindo?');
      expect(normalizeSexo('nao informado'), isNull);
    });
  });
}
