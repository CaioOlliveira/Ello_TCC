import 'package:ello_mobile/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('navega da splash para login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ElloApp()));

    expect(find.text('ello'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1101));
    await tester.pumpAndSettle();

    expect(
      find.text('Transforme o cuidado em uma jornada mais leve!'),
      findsOneWidget,
    );
  });
}
