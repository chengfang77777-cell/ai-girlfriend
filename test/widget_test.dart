import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AiGirlfriendApp());
    // Just verify the app widget builds successfully
    expect(find.byType(AiGirlfriendApp), findsOneWidget);
  });
}
