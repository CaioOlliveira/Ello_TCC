import 'package:ello_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('inicializa o aplicativo e o roteador sem excecao',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ElloApp()));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(find.byType(ElloApp), findsOneWidget);
  });
}
