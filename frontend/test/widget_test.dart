import 'package:flutter_test/flutter_test.dart';
import 'package:muscle_mate/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MuscleMateApp());
    expect(find.text('Muscle Mate'), findsOneWidget);
  });
}
