import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:ai_girlfriend/presentation/widgets/high_five_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    String state = 'idle',
    bool enabled = true,
    Future<bool> Function()? onStart,
    Future<void> Function()? onCancel,
    FocusNode? inputFocus,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            if (inputFocus != null) TextField(focusNode: inputFocus),
            HighFiveControl(
              state: state,
              enabled: enabled,
              onStart: onStart ?? () async => true,
              onCancel: onCancel ?? () async {},
            ),
          ]),
        ),
      ));

  testWidgets('starts once while the viewer acknowledges the request',
      (tester) async {
    var starts = 0;
    final result = Completer<bool>();
    await mount(tester, onStart: () {
      starts++;
      return result.future;
    });

    await tester.tap(find.text('击个掌'));
    await tester.pump();
    expect(find.text('抬手中…'), findsOneWidget);
    await tester.tap(find.text('抬手中…'));
    expect(starts, 1);
    result.complete(true);
    await tester.pump();
  });

  testWidgets('busy chat disables starting a high five', (tester) async {
    var starts = 0;
    await mount(tester, enabled: false, onStart: () async {
      starts++;
      return true;
    });
    await tester.tap(find.text('击个掌'));
    expect(starts, 0);
  });

  for (final state in ['raising', 'waiting']) {
    testWidgets('$state allows cancel even when chat is busy', (tester) async {
      var cancels = 0;
      final result = Completer<void>();
      await mount(tester, state: state, enabled: false, onCancel: () {
        cancels++;
        return result.future;
      });
      if (state == 'waiting') {
        expect(find.text('点击人物掌心'), findsOneWidget);
      }
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.tap(find.text('取消'));
      expect(cancels, 1);
      result.complete();
      await tester.pump();
    });
  }

  for (final state in ['hit', 'returning']) {
    testWidgets('$state offers no repeated start or cancel', (tester) async {
      await mount(tester, state: state);
      expect(find.text('击个掌'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });
  }

  testWidgets('rejected request tells the user the character is not ready',
      (tester) async {
    await mount(tester, onStart: () async => false);
    await tester.tap(find.text('击个掌'));
    await tester.pump();
    expect(find.text('请等角色准备好再试'), findsOneWidget);
    expect(find.text('击个掌'), findsOneWidget);
  });

  testWidgets('mouse activation preserves an already focused input',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(tester, inputFocus: focus);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('击个掌')));
    await mouse.down(tester.getCenter(find.text('击个掌')));
    await mouse.up();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await mouse.removePointer();
  });
}
