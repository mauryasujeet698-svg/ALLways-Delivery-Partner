import 'package:flutter_test/flutter_test.dart';
import 'package:allways_delivery_partner/main.dart';

void main() {
  testWidgets('Delivery login renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    await tester.pump();
    expect(find.text('ALLways Delivery Partner'), findsOneWidget);
  });
}
