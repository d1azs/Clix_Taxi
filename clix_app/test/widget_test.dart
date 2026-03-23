// CLIX Widget Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:clix_app/main.dart';

void main() {
  testWidgets('CLIX app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const CLIXApp());
    // Перевіряємо, що додаток запускається і показує екран логіну
    expect(find.text('Вхід'), findsOneWidget);
  });
}
