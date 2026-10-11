import 'dart:ui' show PointerDeviceKind;

import 'package:ai_girlfriend/presentation/widgets/chat_input.dart';
import 'package:ai_girlfriend/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder getInput() => find.descendant(
        of: find.byType(ChatInput),
        matching: find.byType(TextField),
      );

  FocusNode inputFocus(WidgetTester tester) =>
      tester.widget<TextField>(getInput()).focusNode!;

  Future<void> mount(WidgetTester tester, {Widget? input}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Expanded(
            child: SizedBox.expand(
              child: ColoredBox(color: Colors.white, key: Key('blank')),
            ),
          ),
          input ?? const ChatInput(),
        ]),
      ),
    ));
    await tester.pump();
  }

  testWidgets('input is ready to type on entry', (tester) async {
    await mount(tester);
    expect(inputFocus(tester).hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('platform send keeps focus for the next message', (tester) async {
    final sent = <String>[];
    await mount(tester, input: ChatInput(onSend: sent.add));
    await tester.enterText(getInput(), '  first message  ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sent, ['first message']);
    expect(inputFocus(tester).hasFocus, isTrue);
    expect(tester.widget<TextField>(getInput()).controller!.text, isEmpty);
    tester.testTextInput.enterText('next message');
    await tester.pump();
    expect(
        tester.widget<TextField>(getInput()).controller!.text, 'next message');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('loading Enter preserves focus and next draft without sending',
      (tester) async {
    final loading = ValueNotifier(false);
    addTearDown(loading.dispose);
    final sent = <String>[];
    await mount(tester,
        input: ValueListenableBuilder<bool>(
          valueListenable: loading,
          builder: (context, isLoading, child) => ChatInput(
            isLoading: isLoading,
            onSend: (text) {
              sent.add(text);
              loading.value = true;
            },
          ),
        ));
    await tester.enterText(getInput(), 'first');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    tester.testTextInput.enterText('next draft');
    await tester.pump();

    for (var i = 0; i < 2; i++) {
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(inputFocus(tester).hasFocus, isTrue);
      expect(
          tester.widget<TextField>(getInput()).controller!.text, 'next draft');
      expect(sent, ['first']);
    }
    loading.value = false;
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sent, ['first', 'next draft']);
    expect(inputFocus(tester).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('empty Enter keeps input focus', (tester) async {
    await mount(tester);
    await tester.tap(getInput());
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(inputFocus(tester).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('mouse send keeps input focus', (tester) async {
    final sent = <String>[];
    await mount(tester, input: ChatInput(onSend: sent.add));
    await tester.enterText(getInput(), 'clicked send');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(sent, ['clicked send']);
    expect(inputFocus(tester).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('mouse click on blank space preserves typing focus',
      (tester) async {
    await mount(tester);
    await tester.tap(getInput());
    await tester.pump();
    await tester.tap(find.byKey(const Key('blank')),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(inputFocus(tester).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('dialog can own focus and chat regains it after close',
      (tester) async {
    await mount(tester);
    await tester.tap(getInput());
    final context = tester.element(getInput());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const TextField(autofocus: true, key: Key('dialog-input')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(inputFocus(tester).hasFocus, isFalse);
    await tester.enterText(find.byKey(const Key('dialog-input')), 'setting');
    expect(find.text('setting'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(inputFocus(tester).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('resume restores idle chat focus without stealing other fields',
      (tester) async {
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await mount(tester,
        input: Column(children: [
          TextField(focusNode: otherFocus),
          const ChatInput(),
        ]));
    await tester.tap(getInput());
    inputFocus(tester).unfocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(inputFocus(tester).hasFocus, isTrue);

    otherFocus.requestFocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(otherFocus.hasFocus, isTrue);
    expect(inputFocus(tester).hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('focus border follows focus changes without editing text',
      (tester) async {
    final otherFocus = FocusNode();
    addTearDown(otherFocus.dispose);
    await mount(tester,
        input: Column(children: [
          TextField(focusNode: otherFocus),
          const ChatInput(),
        ]));
    await tester.tap(getInput());
    await tester.pump();
    Color borderColor() {
      final fieldContainer = tester
          .widgetList<Container>(find.ancestor(
            of: getInput(),
            matching: find.byType(Container),
          ))
          .firstWhere((widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).border != null);
      return ((fieldContainer.decoration! as BoxDecoration).border! as Border)
          .top
          .color;
    }

    expect(borderColor(), AppTheme.primaryColor);
    otherFocus.requestFocus();
    await tester.pump();
    expect(borderColor(), Colors.transparent);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'external controller can fill a draft and survives input disposal',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final sent = <String>[];
    await mount(tester,
        input: ChatInput(controller: controller, onSend: sent.add));
    controller.text = 'shared draft';
    await tester.pump();
    expect(find.text('shared draft'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(sent, ['shared draft']);
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.text = 'still owned by the page';
    expect(controller.text, 'still owned by the page');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
