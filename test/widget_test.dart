import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager_pdv_windows/main.dart';

void main() {
  testWidgets('PDV App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PdvApp());
    expect(find.text('FRENTE DE CAIXA / PDV'), findsOneWidget);
  });
}
