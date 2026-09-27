// Opt-in native integration entrypoint. Uses a temporary store and fake HTTP;
// never contacts a model or writes messages to the user's real chat history.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_girlfriend/core/constants.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/domain/chat_provider.dart';
import 'package:ai_girlfriend/presentation/pages/home_page.dart';
import 'package:ai_girlfriend/presentation/widgets/avatar_display.dart';

Element findElement(bool Function(Element) match) {
  Element? found;
  void visit(Element e) {
    if (match(e)) {
      found = e;
      return;
    }
    e.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  if (found == null) throw StateError('Widget not mounted');
  return found!;
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> until(Future<bool> Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!await ready()) {
    if (DateTime.now().isAfter(deadline)) throw StateError('Probe timed out');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final output = File('${docs.path}/windows-chat-probe.log');
  await output.writeAsString('Native HomePage chat integration\n');
  Future<void> log(String value) =>
      output.writeAsString('$value\n', mode: FileMode.append, flush: true);
  final temp = await Directory.systemTemp.createTemp('native_chat_probe_');
  Hive.init(temp.path);
  var exitCode = 0;
  final storage = StorageService();
  final moods = [
    'happy',
    'shy',
    'angry',
    'sad',
    'surprised',
    'refuse',
    'thankful'
  ];
  var replyIndex = 0;
  final api = DeepSeekApi(
      apiKey: 'local-probe-only',
      maxRetries: 1,
      client: MockClient((request) async {
        final body = jsonDecode(request.body);
        check(body['response_format']?['type'] == 'json_object',
            'Missing JSON output contract');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'reply': '这是表情联调测试。',
                      'emotion': moods[replyIndex++],
                      'action': 'talk'
                    })
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
  try {
    await storage.init();
    await storage.setSetting(AppConstants.autoPlayKey, false);
    runApp(ProviderScope(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      currentCharacterIdProvider.overrideWith((ref) => 'preset_01'),
      llmApiProvider.overrideWithValue(api),
    ], child: const MaterialApp(home: HomePage())));
    await Future<void>.delayed(const Duration(seconds: 1));
    final dynamic avatar =
        (findElement((e) => e.widget is AvatarDisplay) as StatefulElement)
            .state;
    await until(() async {
      try {
        return await avatar.windowsController
                ?.executeScript('!!currentVrm?.expressionManager') ==
            true;
      } catch (_) {
        return false;
      }
    });
    final field = findElement((e) => e.widget is TextField).widget as TextField;
    final editor =
        (findElement((e) => e.widget is EditableText) as StatefulElement).state
            as EditableTextState;
    check(field.focusNode!.hasFocus, 'Chat is not focused on entry');
    await log('model ready; input auto-focused');
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      field.controller!.text = '表情测试 $mood';
      editor.performAction(TextInputAction.send);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      check(field.focusNode!.hasFocus, 'Input lost focus after send');
      field.controller!.text = '下一条草稿';
      editor.performAction(TextInputAction.send);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      check(field.focusNode!.hasFocus, 'Input lost focus on loading Enter');
      check(field.controller!.text == '下一条草稿',
          'Loading Enter discarded the draft');
      await until(() async =>
          storage.getMessages('preset_01').where((m) => m.isAssistant).length ==
          i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final face = await avatar.windowsController.executeScript(
              'Object.fromEntries(Object.keys(currentVrm.expressionManager.expressionMap).filter(k=>["happy","sad","angry","relaxed","surprised"].includes(k.toLowerCase())).map(k=>[k,currentVrm.expressionManager.getValue(k)]))')
          as Map;
      final expectedChannel = {
            'shy': 'happy',
            'refuse': 'angry',
            'thankful': 'happy',
            'surprised': 'Surprised'
          }[mood] ??
          mood;
      check((face[expectedChannel] as num) > .18,
          'Emotion did not reach native viewer: $mood $face');
      final weights = face.values.cast<num>();
      check(weights.any((v) => v > .18),
          'Emotion is not visible in native viewer: $face');
      await log(
          'chat -> native face $mood: $face; focus retained, draft retained');
      await Future<void>.delayed(const Duration(milliseconds: 3400));
      final settled = await avatar.windowsController.executeScript(
              '["happy","sad","angry","relaxed","Surprised"].map(k=>currentVrm.expressionManager.getValue(k)||0)')
          as List;
      check(settled.every((v) => v == 0), 'Face did not settle');
    }
    await log(
        'PASS: all 7 expressive replies traversed HomePage; idle neutral; input remains ready');
  } catch (e, stack) {
    exitCode = 1;
    await log('FAIL: $e\n$stack');
  } finally {
    api.dispose();
    runApp(const SizedBox.shrink());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await Hive.close();
    await temp.delete(recursive: true);
    exit(exitCode);
  }
}
