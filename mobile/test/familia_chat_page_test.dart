import 'package:ello_mobile/features/chat/presentation/familia_chat_page.dart';
import 'package:ello_mobile/app/providers.dart';
import 'package:ello_mobile/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost');

  @override
  Future<void> registrarPresenca({required String usuarioId}) async {}

  @override
  Future<List<MembroFicha>> listarConversasFamilia({
    required String idosoId,
    required String usuarioId,
  }) async {
    return const [
      MembroFicha(
        usuarioId: '22222222-2222-2222-2222-222222222222',
        nome: 'Caio Gabriel Sobral de Oliveira',
        eAdministrador: false,
        eCriador: false,
        permissoesVisualizar: [],
        permissoesEditar: [],
        funcao: 'cuidador',
      ),
    ];
  }

  @override
  Future<void> apagarConversaFamilia({
    required String idosoId,
    required String usuarioId,
    required String outroUsuarioId,
  }) async {}

  @override
  Future<List<FamiliaChatMensagem>> listarMensagensFamilia({
    required String idosoId,
    required String usuarioId,
    required String outroUsuarioId,
  }) async {
    return const [];
  }
}

void main() {
  testWidgets('renderiza detalhe do chat da familia sem crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FamiliaChatDetailPage(
            peerId: '11111111-1111-1111-1111-111111111111',
            initialPeer: FamiliaChatPeer(
              id: '11111111-1111-1111-1111-111111111111',
              name: 'Caio Gabriel Sobral de Oliveira',
              role: 'cuidador',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderiza lista do chat da familia sem crash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiClient()),
          authSessionProvider.overrideWith(
            (ref) => const UsuarioSessao(
              id: '11111111-1111-1111-1111-111111111111',
              nome: 'Usuario',
              email: 'u@teste.com',
            ),
          ),
          selectedIdosoProvider.overrideWith(
            (ref) => const IdosoResumo(
              id: '33333333-3333-3333-3333-333333333333',
              nome: 'Maria',
              idade: 80,
              condicoes: [],
            ),
          ),
        ],
        child: const MaterialApp(home: FamiliaChatPage()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
