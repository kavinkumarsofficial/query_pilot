import 'package:flutter_test/flutter_test.dart';
import 'package:query_pilot_example/main.dart';

void main() {
  testWidgets('loads appointments and supports navigation', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Design review'), findsOneWidget);

    await tester.tap(find.text('Design review'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('QueryPilot Example'), findsOneWidget);
  });
}
