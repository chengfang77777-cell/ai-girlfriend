import 'dart:async';
import 'dart:convert';

import 'package:ai_girlfriend/presentation/widgets/study_music_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plugin = MethodChannel('io.jns.webview.win');
  const view = MethodChannel('io.jns.webview.win/77');
  const events = MethodChannel('io.jns.webview.win/77/events');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;

  Future<void> waitForLoad(WidgetTester tester) async {
    for (var i = 0; i < 30 && !calls.any((c) => c.method == 'loadUrl'); i++) {
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(calls.where((c) => c.method == 'loadUrl'), hasLength(1),
        reason: calls.map((c) => c.method).join(', '));
  }

  Future<void> event(String type, dynamic value) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec()
            .encodeSuccessEnvelope({'type': type, 'value': value}),
        (_) {});
  }

  setUp(() {
    // Do not reuse an asset Future created in a preceding test's FakeAsync zone.
    rootBundle.evict('assets/web/js/study-music-bridge.js');
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin,
        (call) async {
      calls.add(call);
      return call.method == 'initialize' ? {'textureId': 77} : null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(view, (call) async {
      calls.add(call);
      return null;
    });
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (_) async => null);
  });

  tearDown(() {
    for (final channel in [plugin, view, events]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> showPanel(WidgetTester tester, {VoidCallback? onClose}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 780,
      height: 600,
      child: StudyMusicPanel(onClose: onClose ?? () {}),
    ))));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'music wheel forwards the pointer position before the scroll delta',
      (tester) async {
    await showPanel(tester);
    await waitForLoad(tester);
    await event('loadingStateChanged', 2);
    await tester.pump();
    await tester.pump();
    calls.clear();
    final topLeft = tester.getTopLeft(find.byType(Webview));
    tester.binding.handlePointerEvent(PointerScrollEvent(
        position: topLeft + const Offset(64, 80),
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(30, 120)));
    await tester.pump();
    await tester.pump();
    final inputs = calls
        .where(
            (c) => c.method == 'setCursorPos' || c.method == 'setScrollDelta')
        .toList();
    expect(inputs.map((c) => c.method), ['setCursorPos', 'setScrollDelta']);
    expect(inputs.first.arguments, [64.0, 80.0]);
    expect(inputs.last.arguments, [-30.0, -120.0]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('trackpad updates target the gesture position without a hover',
      (tester) async {
    await showPanel(tester);
    await waitForLoad(tester);
    await event('loadingStateChanged', 2);
    await tester.pump();
    await tester.pump();
    calls.clear();
    final position =
        tester.getTopLeft(find.byType(Webview)) + const Offset(90, 110);
    tester.binding.handlePointerEvent(PointerPanZoomStartEvent(
        pointer: 88, position: position));
    tester.binding.handlePointerEvent(PointerPanZoomUpdateEvent(
        pointer: 88,
        position: position,
        pan: const Offset(-20, -40),
        panDelta: const Offset(-20, -40)));
    await tester.pump();
    await tester.pump();
    final inputs = calls
        .where(
            (c) => c.method == 'setCursorPos' || c.method == 'setScrollDelta')
        .toList();
    expect(inputs.map((c) => c.method), ['setCursorPos', 'setScrollDelta']);
    expect(inputs.first.arguments, [90.0, 110.0]);
    expect(inputs.last.arguments, [-20.0, -40.0]);
    tester.binding.handlePointerEvent(PointerPanZoomEndEvent(
        pointer: 88, position: position));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('opens official site and releases native player on close',
      (tester) async {
    var closed = false;
    await showPanel(tester, onClose: () => closed = true);
    expect(calls.where((c) => c.method == 'loadUrl').single.arguments,
        'https://music.163.com/st/webplayer');
    await tester.tap(find.byTooltip('关闭音乐'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(closed, isTrue);
    expect(calls.where((c) => c.method == 'dispose'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.where((c) => c.method == 'dispose'), hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('minimize and expand preserve the existing music page',
      (tester) async {
    var minimized = false;
    late StateSetter change;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      change = setState;
      return SizedBox(
          width: 780,
          height: 600,
          child: StudyMusicPanel(
            onClose: () {},
            minimized: minimized,
            onToggleMinimized: () => change(() => minimized = !minimized),
          ));
    })));
    await tester.pump();
    await tester.pump();
    await waitForLoad(tester);
    await tester.tap(find.byTooltip('收起音乐，继续陪学'));
    await tester.pump();
    expect(find.byTooltip('展开音乐'), findsOneWidget);
    expect(calls.where((c) => c.method == 'dispose'), isEmpty);
    await tester.tap(find.byTooltip('展开音乐'));
    await tester.pump();
    expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
    expect(calls.where((c) => c.method == 'loadUrl'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('late initialization is released after panel removal',
      (tester) async {
    final pending = Completer<Map<String, int>>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin,
        (call) async {
      calls.add(call);
      return call.method == 'initialize' ? pending.future : null;
    });
    await showPanel(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete({'textureId': 77});
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(calls.where((c) => c.method == 'loadUrl'), isEmpty);
    expect(calls.where((c) => c.method == 'dispose'), hasLength(1));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('initialization failure offers retry and then opens music',
      (tester) async {
    var attempts = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(plugin,
        (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        if (attempts++ == 0) throw PlatformException(code: 'runtime_missing');
        return {'textureId': 77};
      }
      return null;
    });
    await showPanel(tester);
    expect(find.text('重新连接'), findsOneWidget);
    await tester.tap(find.text('重新连接'));
    await tester.pump();
    await waitForLoad(tester);
    await tester.pump();
    expect(calls.where((c) => c.method == 'loadUrl'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'minimized player receives live metadata and waits for command acknowledgement',
      (tester) async {
    var title = '测试歌曲';
    var pageVolume = .6;
    final commands = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(view, (call) async {
      calls.add(call);
      if (call.method != 'executeScript') return null;
      final script = call.arguments as String;
      if (script.contains('snapshot()')) {
        return jsonEncode({
          'title': title,
          'artist': '测试歌手',
          'playing': true,
          'volume': pageVolume,
          'canNext': true,
          'canPrevious': true,
          'canToggle': true,
          'canVolume': true
        });
      }
      if (script.contains('studyMusicCommand')) {
        commands.add(script);
        title = '切换后的歌曲';
        final id = int.parse(RegExp(r'id:(\d+)').firstMatch(script)!.group(1)!);
        await event('webMessageReceived',
            jsonEncode({'type': 'studyMusicCommand', 'id': id, 'ok': true}));
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 360,
                height: 208,
                child: StudyMusicPanel(
                    onClose: () {},
                    minimized: true,
                    onToggleMinimized: () {})))));
    await waitForLoad(tester);
    await event('loadingStateChanged', 2);
    await tester.pump();
    await tester.pump();
    expect(find.text('测试歌曲'), findsOneWidget);
    await tester.tap(find.byTooltip('下一首'));
    await tester.pump();
    await tester.pump();
    expect(commands.single, contains('"next"'));
    expect(find.text('切换后的歌曲'), findsOneWidget);
    pageVolume = .8;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
        tester.widget<Slider>(find.byKey(const Key('music-volume'))).value, .8);
    expect(commands, hasLength(1),
        reason: 'Observing page volume must not write an older value back.');
    await event('loadingStateChanged', 1);
    await tester.pump();
    await tester.pump();
    expect(find.text('切换后的歌曲'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('lost music command acknowledgement times out and permits retry',
      (tester) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(view, (call) async {
      calls.add(call);
      if (call.method == 'executeScript' &&
          (call.arguments as String).contains('snapshot()')) {
        return jsonEncode(
            {'title': '测试歌曲', 'playing': true, 'volume': .5, 'canNext': true});
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 360,
                height: 208,
                child: StudyMusicPanel(
                    onClose: () {},
                    minimized: true,
                    onToggleMinimized: () {})))));
    await waitForLoad(tester);
    await event('loadingStateChanged', 2);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('下一首'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('操作未完成，请展开网易云操作'), findsOneWidget);
    final next = tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '下一首'));
    expect(next.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
