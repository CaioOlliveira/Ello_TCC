import 'package:ello_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('navega da splash para login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ElloApp()));

    expect(find.text('Ello'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(
      find.text('Transforme o cuidado em uma jornada mais leve!'),
      findsOneWidget,
    );
  });
}
