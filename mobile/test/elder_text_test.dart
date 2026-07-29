import 'package:ello_mobile/core/utils/elder_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ElderText', () {
    test('flexiona textos para idosa', () {
      final text = ElderText.fromSexo('Feminino');

      expect(text.singular, 'idosa');
      expect(text.of, 'da idosa');
      expect(text.howFeeling(), 'Como a idosa está se sentindo?');
      expect(normalizeSexo('idosa'), 'Feminino');
    });

    test('flexiona textos para idoso', () {
      final text = ElderText.fromSexo('M');

      expect(text.singular, 'idoso');
      expect(text.of, 'do idoso');
      expect(text.howFeeling(), 'Como o idoso está se sentindo?');
      expect(normalizeSexo('idoso'), 'Masculino');
    });

    test('usa pessoa idosa quando o sexo nao esta definido', () {
      final text = ElderText.fromSexo(null);

      expect(text.singular, 'pessoa idosa');
      expect(text.selectedWithArticle, 'a pessoa idosa selecionada');
      expect(text.howFeeling(), 'Como a pessoa idosa está se sentindo?');
      expect(normalizeSexo('nao informado'), isNull);
    });
  });
}
