import 'package:ello_mobile/app/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restaura a sessão salva e a remove no logout', () async {
    final storage = SessaoUsuarioLocal();
    const usuario = UsuarioSessao(
      id: 'usuario-1',
      nome: 'Caio',
      email: 'caio@exemplo.com',
      telefone: '11999999999',
      sexo: 'Masculino',
    );

    await storage.salvar(usuario);
    final restaurado = await storage.carregar();

    expect(restaurado?.id, usuario.id);
    expect(restaurado?.nome, usuario.nome);
    expect(restaurado?.sexo, usuario.sexo);

    await storage.limpar();

    expect(await storage.carregar(), isNull);
  });
}
