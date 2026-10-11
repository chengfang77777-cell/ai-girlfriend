import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/presentation/widgets/chat_wheel_region.dart';

void main() {
  testWidgets('sidebar native wheel scrolls once and Ctrl only zooms',
      (tester) async {
    final controller = ScrollController();
    final zooms = <double>[];
    await tester.pumpWidget(MaterialApp(
        home: ChatWheelRegion(
      controller: controller,
      onModelZoom: zooms.add,
      nativeScrolling: true,
      child: ListView(
          controller: controller, children: const [SizedBox(height: 3000)]),
    )));
    void wheel() => tester.binding.handlePointerEvent(const PointerScrollEvent(
        position: Offset(200, 200), scrollDelta: Offset(0, 100)));
    wheel();
    await tester.pump();
    expect(controller.offset, 100);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    wheel();
    await tester.pump();
    expect(controller.offset, 100);
    expect(zooms, [100]);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('wheel scrolls messages; either Ctrl key routes only to model',
      (tester) async {
    final controller = ScrollController();
    final zooms = <double>[];
    var dragCount = 0;
    await tester.pumpWidget(MaterialApp(
        home: ChatWheelRegion(
      controller: controller,
      onModelZoom: zooms.add,
      child: Stack(children: [
        Positioned.fill(
            child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (_) => dragCount++,
          child: const SizedBox.expand(),
        )),
        IgnorePointer(
            child: ListView(
          controller: controller,
          children: const [SizedBox(height: 3000)],
        )),
      ]),
    )));
    Future<void> wheel(double delta) async {
      tester.binding.handlePointerEvent(PointerScrollEvent(
        position: const Offset(200, 200),
        scrollDelta: Offset(0, delta),
      ));
      await tester.pump();
    }

    await wheel(120);
    expect(controller.offset, 120);
    expect(zooms, isEmpty);
    for (final key in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight
    ]) {
      await tester.sendKeyDownEvent(key);
      await wheel(-80);
      expect(controller.offset, 120);
      await tester.sendKeyUpEvent(key);
    }
    expect(zooms, [-80, -80]);
    await wheel(100000);
    expect(controller.offset, controller.position.maxScrollExtent);
    await wheel(-100000);
    expect(controller.offset, 0);
    await tester.dragFrom(const Offset(200, 200), const Offset(80, 20));
    expect(dragCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
