import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long messages fit a narrow panel in a desktop window',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 380,
            child: ListView(
              children: MessageType.values
                  .map((type) => ChatBubble(
                        message: '这是一条需要在窄聊天栏里正确换行的长消息。' * 6,
                        type: type,
                        timestamp: DateTime(2026, 9, 29, 10, 30),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final element in find.byType(ChatBubble).evaluate()) {
      final message = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.text('这是一条需要在窄聊天栏里正确换行的长消息。' * 6),
      );
      expect(tester.getSize(message).width, greaterThan(200));
      expect(tester.getRect(message).right, lessThanOrEqualTo(1440));
    }
  });
}
