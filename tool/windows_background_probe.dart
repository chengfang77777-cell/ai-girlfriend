// Visual and lifecycle verification using local models and isolated chat data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:ai_girlfriend/core/backgrounds.dart';
import 'package:ai_girlfriend/core/constants.dart';
import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/domain/chat_provider.dart';
import 'package:ai_girlfriend/domain/background_provider.dart';
import 'package:ai_girlfriend/models/message.dart';
import 'package:ai_girlfriend/presentation/pages/home_page.dart';
import 'package:ai_girlfriend/presentation/widgets/avatar_display.dart';
import 'windows_chat_probe.dart' show findElement, check, until;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final previews = await Directory('${docs.path}/companion-background-preview')
      .create(recursive: true);
  final output = File('${previews.path}/verification.log');
  await output.writeAsString('Native companion background verification\n');
  Future<void> log(String value) =>
      output.writeAsString('$value\n', mode: FileMode.append, flush: true);
  final temp = await Directory.systemTemp.createTemp('background_preview_');
  Hive.init(temp.path);
  final storage = StorageService();
  final api = DeepSeekApi(
      apiKey: 'local-probe-only',
      client: MockClient((request) async => http.Response('{}', 500)));
  final screen = GlobalKey();
  final narrow = ValueNotifier(false);
  var code = 0;
  Future<void> capture(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final image = await (screen.currentContext!.findRenderObject()
            as RenderRepaintBoundary)
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${previews.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  }

  try {
    await storage.init();
    await storage.setSetting(AppConstants.autoPlayKey, false);
    for (final (index, role, text) in [
      (0, 'user', '今天有点累，想在这里待一会儿。'),
      (1, 'assistant', '那就歇一会儿吧。慢慢说也好，安静坐着也好，我陪着你。')
    ]) {
      await storage.addMessage(Message(
          id: 'preview-$index',
          characterId: 'preset_01',
          role: role,
          content: text,
          timestamp: DateTime(2026, 10, 3, 20, 30, index)));
    }
    runApp(ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          currentCharacterIdProvider.overrideWith((ref) => 'preset_01'),
          llmApiProvider.overrideWithValue(api)
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(
                key: screen,
                child: ValueListenableBuilder<bool>(
                    valueListenable: narrow,
                    builder: (context, small, _) => Align(
                        child: SizedBox(
                            width: small ? 430 : null,
                            child: const HomePage())))))));
    await Future<void>.delayed(const Duration(seconds: 1));
    final dynamic avatar =
        (findElement((e) => e.widget is AvatarDisplay) as StatefulElement)
            .state;
    Future<dynamic> js(String script) async =>
        await avatar.windowsController.executeScript(script);
    Future<Map> state() async =>
        await js('window.companionBackground.getState()') as Map;
    await until(() async {
      try {
        return await js(
                '!!currentVrm?.humanoid && !!window.companionBackground') ==
            true;
      } catch (_) {
        return false;
      }
    });
    await Future<void>.delayed(const Duration(seconds: 3));
    await log(
        'Initial motion settings: ${await state()}; visibility=${await js("document.visibilityState")}; systemReduced=${await js("matchMedia('(prefers-reduced-motion: reduce)').matches")}');
    check(
        (await state())['motionMode'] == 'gentle' &&
            (await state())['reducedMotion'] == false,
        'Default app preference did not enable gentle motion');
    check(
        await js(
                'window.getComputedStyle(document.querySelector("#bg-canvas")).pointerEvents') ==
            'none',
        'Background must not intercept character input');
    for (final preset in PresetBackgrounds.all) {
      await js('window.setBackground(${jsonEncode(preset.id)})');
      await until(() async => (await state())['transition'] == 1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final before = await state();
      final startedAt = await js('performance.now()') as num;
      check(before['id'] == preset.id, 'Wrong preset');
      final first = await js('document.querySelector("#bg-canvas").toDataURL()')
          as String;
      await File('${previews.path}/${preset.id}-background.png')
          .writeAsBytes(base64Decode(first.split(',').last));
      await capture(preset.id);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final second =
          await js('document.querySelector("#bg-canvas").toDataURL()')
              as String;
      check(first != second,
          'Preset has no moving atmosphere: ${preset.id}: ${await state()}');
      check(
          ((await state())['frames'] as int) - (before['frames'] as int) <=
              (((await js('performance.now()') as num) - startedAt) * .03)
                      .ceil() +
                  2,
          'Background paints above its frame budget');
      await log('PASS ${preset.id}: ${await state()}');
    }
    await js(
        'window.setBackground("sakura_falling");window.setBackground("cozy_room");window.setBackground("fresh_meadow");');
    await until(() async => (await state())['transition'] == 1);
    check((await state())['id'] == 'fresh_meadow',
        'Rapid switching did not settle');
    final webBox =
        findElement((e) => e.widget is Webview).renderObject! as RenderBox;
    final ambientPoint = webBox.localToGlobal(
        Offset(webBox.size.width * .2, webBox.size.height * .25));
    GestureBinding.instance.handlePointerEvent(PointerHoverEvent(
        position: ambientPoint, kind: PointerDeviceKind.mouse));
    await until(() async => (await state())['hover'] as num > .5);
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 92,
        position: ambientPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 92, position: ambientPoint, kind: PointerDeviceKind.mouse));
    await until(() async => (await state())['blooms'] as num > 0);
    await log(
        'PASS: actual Flutter mouse hover/click reached the native webpage');
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    Future<void> pointer(String type, {double x = 190, double y = 200}) async {
      await js('window.dispatchEvent(new PointerEvent(${jsonEncode(type)},'
          '{clientX:$x,clientY:$y,pointerId:17,isPrimary:true,button:0}));');
    }

    await pointer('pointermove');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    check((await state())['hover'] as num > .5,
        'Pointer hover light did not respond');
    await pointer('pointerdown');
    await pointer('pointerup');
    check(
        (await state())['blooms'] == 1, 'Primary tap did not emit warm bloom');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await capture('warm-interaction');
    await pointer('pointerleave');
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    check((await state())['blooms'] == 0, 'Interaction glow did not expire');
    check((await state())['hover'] as num < .01,
        'Hover light did not fade after leaving');
    await pointer('pointerdown');
    await pointer('pointermove', x: 260);
    await pointer('pointerup', x: 260);
    check(
        (await state())['blooms'] == 0, 'Model dragging emitted a click bloom');
    await pointer('pointerleave');
    await log(
        'PASS: pointer hover, primary tap, expiry, leave and drag rejection');
    await js('window.setStudyQuiet(true)');
    await Future<void>.delayed(const Duration(seconds: 2));
    check((await state())['motion'] as num < .35,
        'Study atmosphere failed to slow down');
    await pointer('pointerdown');
    await pointer('pointerup');
    check(
        (await state())['blooms'] == 0, 'Study mode emitted an ambient bloom');
    await js('window.setStudyQuiet(false)');
    final container =
        ProviderScope.containerOf(findElement((e) => e.widget is HomePage));
    container.read(backgroundMotionProvider.notifier).state =
        BackgroundMotion.still;
    await until(() async => (await state())['motionMode'] == 'still');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final staticFrame =
        await js('document.querySelector("#bg-canvas").toDataURL()');
    await pointer('pointermove');
    await pointer('pointerdown');
    await pointer('pointerup');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    check(
        await js('document.querySelector("#bg-canvas").toDataURL()') ==
            staticFrame,
        'Reduced motion still animates');
    await js('window.setBackground("ice_world")');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    check((await state())['transition'] == 1,
        'Reduced motion should switch immediately');
    container.read(backgroundMotionProvider.notifier).state =
        BackgroundMotion.system;
    await until(() async => (await state())['motionMode'] == 'system');
    check(
        (await state())['reducedMotion'] ==
            await js("matchMedia('(prefers-reduced-motion: reduce)').matches"),
        'Follow-system preference did not match the OS');
    container.read(backgroundMotionProvider.notifier).state =
        BackgroundMotion.gentle;
    await until(() async => (await state())['motionMode'] == 'gentle');
    narrow.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    check((await state())['width'] as num < 500,
        'Background did not follow a narrow window');
    await capture('narrow-window');
    narrow.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    check((await state())['width'] as num > 500,
        'Background did not recover after resize');
    final field = findElement((e) => e.widget is TextField).widget as TextField;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    await log(
        'Input focus: ${field.focusNode!.hasFocus}; lifecycle=$lifecycle');
    // An inactive native window suspends Flutter keyboard focus. The background
    // cannot restore it without stealing focus from the user's other window.
    if (lifecycle == AppLifecycleState.resumed) {
      check(field.focusNode!.hasFocus, 'Visual effect stole chat input focus');
    } else {
      await log(
          'Inactive window: keyboard focus retention covered by widget regressions');
    }
    await log(
        'PASS: eight moving presets, non-intercepting canvas, rapid switches, quiet study, reduced motion and narrow/wide resizing');
  } catch (error, stack) {
    code = 1;
    await log('FAIL: $error\n$stack');
  } finally {
    runApp(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    api.dispose();
    narrow.dispose();
    await Hive.close();
    final resolvedTemp = await temp.resolveSymbolicLinks();
    final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
    if (resolvedTemp
        .startsWith('$tempRoot${Platform.pathSeparator}background_preview_')) {
      await temp.delete(recursive: true);
    }
    exit(code);
  }
}
