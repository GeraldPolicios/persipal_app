import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/main.dart';

void main() {
  testWidgets('Persipal app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PersipalApp());

    expect(find.byType(PersipalApp), findsOneWidget);
  });
}
