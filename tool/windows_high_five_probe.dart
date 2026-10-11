// Opt-in native integration probe; isolated storage and no network AI requests.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_girlfriend/core/constants.dart';
import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/domain/chat_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/presentation/pages/home_page.dart';
import 'package:ai_girlfriend/presentation/widgets/avatar_display.dart';
import 'package:ai_girlfriend/presentation/widgets/high_five_control.dart';
import 'package:ai_girlfriend/presentation/widgets/study_panel.dart';
import 'windows_chat_probe.dart' show findElement, check, until;
import 'windows_music_probe.dart' show verifyStudyMusicBridge;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final output = File('${docs.path}/windows-high-five-probe.log');
  await output.writeAsString('Native high-five integration\n');
  Future<void> log(String s) =>
      output.writeAsString('$s\n', mode: FileMode.append, flush: true);
  final temp = await Directory.systemTemp.createTemp('native_high_five_probe_');
  Hive.init(temp.path);
  final storage = StorageService();
  final screenKey = GlobalKey();
  Future<void> capture(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        screenKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${docs.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  }

  var studyPromptSeen = false;
  final api = DeepSeekApi(
      apiKey: 'probe',
      maxRetries: 1,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        studyPromptSeen = (body['messages'] as List).any((m) =>
            m['role'] == 'system' &&
            (m['content'] as String).contains('聊天期间计时继续'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'reply': '谢谢你愿意和我分享，我陪你慢慢来。',
                      'emotion': 'happy',
                      'action': 'thankful'
                    })
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
  var exitCode = 0;
  try {
    await storage.init();
    await storage.setSetting(AppConstants.autoPlayKey, false);
    runApp(ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          currentCharacterIdProvider.overrideWith((ref) => 'preset_01'),
          llmApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(key: screenKey, child: const HomePage()))));
    await Future<void>.delayed(const Duration(seconds: 1));
    final dynamic avatar =
        (findElement((e) => e.widget is AvatarDisplay) as StatefulElement)
            .state;
    Future<dynamic> js(String s) async =>
        await avatar.windowsController.executeScript(s);
    HighFiveControl control() =>
        findElement((e) => e.widget is HighFiveControl).widget
            as HighFiveControl;
    await until(() async {
      try {
        return await avatar.startHighFive() == true;
      } catch (_) {
        return false;
      }
    });
    await until(() async => control().state != 'idle');
    await avatar.cancelHighFive();
    await until(() async => control().state == 'idle');
    await log('Ready: ${await js("window.highFiveStatus()")}');
    await capture('companion-home-ui');
    final field = findElement((e) => e.widget is TextField).widget as TextField;
    check(field.focusNode!.hasFocus, 'Input not focused on entry');
    field.controller!.text = '保留这条草稿';
    // Send an actual Flutter mouse gesture through the start button hit test.
    final button = findElement((e) =>
        e.widget is TextButton && (e.widget as TextButton).onPressed != null);
    final box = button.renderObject! as RenderBox;
    final point = box.localToGlobal(box.size.center(Offset.zero));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 71,
        position: point,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 71, position: point, kind: PointerDeviceKind.mouse));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await log(
        'After start button: ${await js("window.highFiveStatus()")}; UI=${control().state}');
    await until(() async => control().state == 'waiting');
    check(field.focusNode!.hasFocus, 'Starting interaction stole typing focus');
    await log(
        'Flutter mouse start -> native raising -> waiting; typing focus retained');
    check(await avatar.startHighFive() == false, 'Duplicate start accepted');
    final status = await js('window.highFiveStatus()') as Map;
    check(
        status['palm']['visible'] == true, 'Native palm target is not visible');
    // Route mouse events through the Flutter WebView texture and native plugin.
    final avatarBox = findElement((e) => e.widget is AvatarDisplay)
        .renderObject! as RenderBox;
    final scale = await js('window.devicePixelRatio') as num;
    final viewScale =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final palmPoint = avatarBox.localToGlobal(Offset(
      (status['palm']['x'] as num).toDouble() * scale / viewScale,
      (status['palm']['y'] as num).toDouble() * scale / viewScale,
    ));
    GestureBinding.instance.handlePointerEvent(
        PointerHoverEvent(position: palmPoint, kind: PointerDeviceKind.mouse));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 72,
        position: palmPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 72, position: palmPoint, kind: PointerDeviceKind.mouse));
    await until(() async => control().state == 'hit');
    await log('Native canvas palm hit -> Flutter success state');
    await log(
        'After hit focus=${field.focusNode!.hasFocus}; lifecycle=${WidgetsBinding.instance.lifecycleState}; primary=${FocusManager.instance.primaryFocus}');
    await until(() async => control().state == 'idle');
    await Future<void>.delayed(const Duration(seconds: 4));
    check(
        await js('(currentVrm.expressionManager.getValue("happy")||0)===0') ==
            true,
        'Smile stayed active');
    check(field.controller!.text == '保留这条草稿', 'Interaction discarded draft');
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      final foreground = await const MethodChannel('ai_girlfriend/window_focus')
          .invokeMethod<bool>('restoreInputFocus');
      check(
          foreground == false, 'Background probe unexpectedly owns foreground');
      await log('Background window correctly did not steal OS focus');
      // Hidden probes cannot require OS foreground. Exercise the same resume
      // notification delivered when the user returns, without activating a window.
      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(() async => field.focusNode!.hasFocus);
      await log('Simulated app resume restored the existing input and draft');
    }
    check(field.focusNode!.hasFocus,
        'Typing focus lost after interaction; lifecycle=${WidgetsBinding.instance.lifecycleState}; primary=${FocusManager.instance.primaryFocus}');
    check(await control().onStart(), 'Restart failed');
    await until(() async => control().state == 'waiting');
    await control().onCancel();
    await until(() async => control().state == 'idle');
    await log('Cancellation returned to idle');
    check(await control().onStart(), 'Timeout test start failed');
    await until(() async => control().state == 'waiting');
    await until(() async => control().state == 'idle');
    await log('Unanswered palm timed out and lowered naturally');
    check(await control().onStart(), 'Chat interruption start failed');
    await js('window.onUserSendMessage()');
    await until(() async => control().state == 'idle');
    await log(
        'PASS: native mouse/bridge, start/hit/cancel/timeout/chat interruption, brief smile, background focus guard, resume and draft');
    await storage.setSetting('study_session:preset_01', {
      'version': 1,
      'durationMilliseconds': 60000,
      'elapsedMilliseconds': 52000,
      'goal': '读一小段书',
      'phase': 'paused',
    });
    void pressLabel(String label) {
      final text = findElement(
          (e) => e.widget is Text && (e.widget as Text).data == label);
      ButtonStyleButton? button;
      text.visitAncestorElements((e) {
        if (e.widget is ButtonStyleButton) {
          button = e.widget as ButtonStyleButton;
          return false;
        }
        return true;
      });
      check(button?.onPressed != null, 'Button unavailable: $label');
      button!.onPressed!();
    }

    await js('''window._probeCompletions=0;window._probeNotes=0;
      const celebrate=window.celebrateStudyCompletion;
      window.celebrateStudyCompletion=(id)=>{window._probeCompletions++;return celebrate(id);};
      const create=window.AudioContext.prototype.createOscillator;
      window.AudioContext.prototype.createOscillator=function(){window._probeNotes++;return create.call(this);};''');
    pressLabel('陪我学习');
    await until(() async {
      try {
        return findElement((e) => e.widget is StudyPanel).mounted;
      } catch (_) {
        return false;
      }
    });
    final currentAvatar =
        (findElement((e) => e.widget is AvatarDisplay) as StatefulElement)
            .state;
    check(identical(currentAvatar, avatar),
        'Study mode replaced the avatar WebView');
    check(await js('window._probeCompletions') == 0,
        'Restore replayed completion');
    pressLabel('继续学习');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    check(
        (findElement((e) => e.widget is AvatarDisplay).widget as AvatarDisplay)
            .studyQuiet,
        'Study did not become quiet');
    check(await avatar.startHighFive() == false, 'High five interrupted focus');
    final studyInput =
        findElement((e) => e.widget.key == const Key('study-draft')).widget
            as TextField;
    await js('''(() => {
      const original = window.triggerAction;
      window._probeStudyActions = [];
      window.triggerAction = (...args) => {
        window._probeStudyActions.push(args);
        return original(...args);
      };
    })()''');
    studyInput.controller!.text = '谢谢你陪着我，我感觉好多了';
    studyInput.onSubmitted!(studyInput.controller!.text);
    await until(() async {
      try {
        return findElement((e) =>
            e.widget is SelectableText &&
            (e.widget as SelectableText).data == '谢谢你愿意和我分享，我陪你慢慢来。').mounted;
      } catch (_) {
        return false;
      }
    });
    check(studyPromptSeen, 'Missing study context in native chat request');
    await until(() async => await js('window._probeStudyActions.length') == 1);
    check(await js('window._probeStudyActions[0][0]') == 'thankful',
        'Study action was replaced by talk');
    check(await js('window._probeStudyActions[0][1]') == 'happy',
        'Study emotion lost');
    await log(
        'PASS: study chat action thankful + happy reached native avatar while countdown remains active');
    check(
        (storage.getSetting<dynamic>('study_session:preset_01')
                as Map)['phase'] ==
            'focusing',
        'Chat paused study countdown');
    check(
        (findElement((e) => e.widget is AvatarDisplay).widget as AvatarDisplay)
            .studyQuiet,
        'Chat enabled random idle interruptions');
    await capture('companion-study-ui');
    await until(() async => await js('window._probeCompletions') == 1);
    check(await js('window._probeNotes') == 2,
        'Completion did not schedule its two local notes');
    check(
        !(findElement((e) => e.widget is AvatarDisplay).widget as AvatarDisplay)
            .studyQuiet,
        'Completed study remained quiet');
    final praise = findElement((e) =>
        e.widget is SelectableText &&
        ((e.widget as SelectableText).data ?? '').contains('学习计时完成'));
    check(praise.mounted, 'No immediate offline praise');
    await Future<void>.delayed(const Duration(seconds: 3));
    check(await js('window._probeCompletions') == 1,
        'Completion fired more than once');
    final panel =
        findElement((e) => e.widget is StudyPanel).widget as StudyPanel;
    panel.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final restoredInput =
        findElement((e) => e.widget is TextField).widget as TextField;
    check(restoredInput.controller!.text == '保留这条草稿',
        'Mode switch discarded ordinary draft');
    pressLabel('陪我学习');
    await Future<void>.delayed(const Duration(seconds: 1));
    check(await js('window._probeCompletions') == 1,
        'Reopening replayed completion');
    await log(
        'PASS: native study overlay retains avatar, restores paused, quiet focus blocks high five, timer emits two local chime notes and offline praise exactly once; reopening never repeats celebration');
    await verifyStudyMusicBridge(docs, log);
  } catch (e, stack) {
    exitCode = 1;
    await log('FAIL: $e\n$stack');
    await log(
        'Failure focus=${FocusManager.instance.primaryFocus}; lifecycle=${WidgetsBinding.instance.lifecycleState}');
  } finally {
    runApp(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await Hive.close();
    api.dispose();
    await temp.delete(recursive: true);
    exit(exitCode);
  }
}
