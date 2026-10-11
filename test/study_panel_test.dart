import 'dart:async';
import 'dart:convert';

import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/domain/chat_provider.dart';
import 'package:ai_girlfriend/models/character.dart';
import 'package:ai_girlfriend/presentation/widgets/study_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStorage implements StorageService {
  final values = <String, dynamic>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values[key] as T? ?? defaultValue;
  @override
  Future<void> setSetting(String key, dynamic value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const character = Character(
    id: 'study',
    name: '小夏',
    personalityTags: ['温柔'],
    speakingStyle: '自然',
    avatarModelPath: 'unused');

http.Response reply(String text) => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'reply': text, 'emotion': 'neutral'})
          }
        }
      ]
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  late MemoryStorage storage;
  late List<bool> quiet;
  late List<String> spoken;
  late List<String> callbackOrder;
  late List<String> actions;
  setUp(() {
    storage = MemoryStorage();
    quiet = [];
    spoken = [];
    callbackOrder = [];
    actions = [];
  });
  Future<void> mount(WidgetTester tester, {DeepSeekApi? api}) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          currentCharacterProvider.overrideWithValue(character),
          llmApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
              width: 380,
              height: 950,
              child: StudyPanel(
                onClose: () {},
                onMessageStart: () => callbackOrder.add('message-start'),
                onQuietChanged: (value) {
                  quiet.add(value);
                  callbackOrder.add('quiet:$value');
                },
                onReply: (text, emotion, celebrate, action) async {
                  actions.add(action);
                  spoken.add(text);
                  callbackOrder.add(celebrate ? 'celebrate' : 'reply');
                },
              )),
        )))));
    await tester.pump();
  }

  testWidgets('study reply retains its content action in conversation history',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final api = DeepSeekApi(
        apiKey: 'test',
        maxRetries: 1,
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'reply': '谢谢你愿意和我说这些。',
                        'emotion': 'happy',
                        'action': 'thankful',
                      })
                    }
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await mount(tester, api: api);
    await tester.tap(find.text('开始陪学'));
    await tester.pump();
    for (final text in ['谢谢你陪我', '继续陪我吧']) {
      await tester.enterText(find.byKey(const Key('study-draft')), text);
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();
    }
    final history = (bodies.last['messages'] as List)
        .firstWhere((m) => m['role'] == 'assistant');
    expect(jsonDecode(history['content'])['action'], 'thankful');
    expect(actions, ['thankful', 'thankful']);
    expect(quiet.last, isTrue);
    expect(storage.values['study_session:study']['phase'], 'focusing');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom timer starts quietly, pauses and keeps the draft',
      (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(const Key('study-minutes')), '7');
    await tester.enterText(find.byKey(const Key('study-goal')), '读两页书');
    await tester.enterText(find.byKey(const Key('study-draft')), '我有点累');
    await tester.tap(find.text('开始陪学'));
    await tester.pump();
    expect(find.text('07:00'), findsOneWidget);
    expect(quiet.last, isTrue);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(quiet.last, isFalse);
    expect(find.text('我有点累'), findsOneWidget);
    expect(storage.values['study_session:study'], isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('retry repeats exact failed message once and keeps next draft',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final api = DeepSeekApi(
        apiKey: 'test',
        maxRetries: 1,
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (bodies.length == 1) throw Exception('offline');
          return reply('卡住的时候确实会烦，我听着。');
        }));
    await mount(tester, api: api);
    await tester.enterText(find.byKey(const Key('study-draft')), '看不懂，好烦');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('study-draft')), '下一句草稿');
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(bodies.length, 2);
    final messages = bodies.last['messages'] as List;
    expect(messages.where((m) => m['content'] == '看不懂，好烦').length, 1);
    expect(find.text('看不懂，好烦'), findsOneWidget);
    expect(find.text('下一句草稿'), findsOneWidget);
    expect(spoken, ['卡住的时候确实会烦，我听着。']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('returning to focus suppresses a late support response',
      (tester) async {
    final pending = Completer<http.Response>();
    final api = DeepSeekApi(
        apiKey: 'test',
        maxRetries: 1,
        client: MockClient((_) => pending.future));
    await mount(tester, api: api);
    await tester.tap(find.text('开始陪学'));
    await tester.pump();
    await tester.tap(find.text('我学不下去了'));
    await tester.pump();
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.tap(find.text('继续学习'));
    await tester.pump();
    pending.complete(reply('迟来的安慰'));
    await tester.pumpAndSettle();
    expect(quiet.last, isTrue);
    expect(spoken, isEmpty);
    expect(find.text('迟来的安慰'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a restored short countdown praises locally exactly once',
      (tester) async {
    storage.values['study_session:study'] = {
      'durationMilliseconds': 1,
      'elapsedMilliseconds': 0,
      'goal': '读书',
      'phase': 'focusing',
    };
    await mount(tester);
    expect(spoken, isEmpty);
    await tester.tap(find.text('继续学习'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(seconds: 1));
    expect(spoken, hasLength(1));
    expect(quiet.last, isFalse);
    expect(find.text(spoken.single), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(spoken, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  for (final typed in [true, false]) {
    testWidgets(
        '${typed ? 'typed chat' : 'support button'} keeps counting while waiting and replying',
        (tester) async {
      final pending = Completer<http.Response>();
      final requests = <Map<String, dynamic>>[];
      final api = DeepSeekApi(
          apiKey: 'test',
          maxRetries: 1,
          client: MockClient((request) {
            requests.add(jsonDecode(request.body) as Map<String, dynamic>);
            return pending.future;
          }));
      await mount(tester, api: api);
      await tester.tap(find.text('开始陪学'));
      await tester.pump();
      if (typed) {
        await tester.enterText(
            find.byKey(const Key('study-draft')), '有点无聊，陪我说一句');
        await tester.tap(find.byTooltip('发送'));
      } else {
        await tester.tap(find.text('我学不下去了'));
      }
      await tester.pump();
      expect(storage.values['study_session:study']['phase'], 'focusing');
      expect(find.text('暂停'), findsOneWidget);
      expect(quiet, [true], reason: 'A message must not toggle quiet mode.');
      expect(callbackOrder.where((event) => event == 'message-start'),
          hasLength(1));
      final systemMessages = (requests.single['messages'] as List)
          .where((message) => message['role'] == 'system')
          .map((message) => message['content'] as String)
          .join('\n');
      expect(systemMessages, contains('计时继续'));
      expect(systemMessages, contains('不把用户拉入长篇闲聊'));
      pending.complete(reply('我在呢，慢慢来就好。'));
      await tester.pumpAndSettle();
      expect(spoken, ['我在呢，慢慢来就好。']);
      expect(find.text('暂停'), findsOneWidget);
      expect(quiet, [true]);
      await tester.ensureVisible(find.text('暂停'));
      await tester.tap(find.text('暂停'));
      await tester.pump();
      expect(storage.values['study_session:study']['phase'], 'paused');
      expect(quiet.last, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'expiry while chat is pending celebrates once and ignores late reply',
      (tester) async {
    storage.values['study_session:study'] = {
      'durationMilliseconds': 1,
      'elapsedMilliseconds': 0,
      'goal': '读书',
      'phase': 'focusing',
    };
    final pending = Completer<http.Response>();
    final api = DeepSeekApi(
        apiKey: 'test',
        maxRetries: 1,
        client: MockClient((_) => pending.future));
    await mount(tester, api: api);
    await tester.tap(find.text('继续学习'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('study-draft')), '陪我一下');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(spoken, isEmpty);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(seconds: 1));
    expect(callbackOrder.where((event) => event == 'celebrate'), hasLength(1));
    expect(spoken, hasLength(1));
    pending.complete(reply('迟来的闲聊'));
    await tester.pumpAndSettle();
    expect(spoken, hasLength(1));
    expect(find.text('迟来的闲聊'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clearing progress stays cleared after closing', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(const Key('study-goal')), '旧目标');
    await tester.tap(find.text('开始陪学'));
    await tester.pump();
    await tester.tap(find.byTooltip('清除陪学记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收起陪学'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(storage.values['study_session:study'], isNull);
  });

  testWidgets('pausing at the deadline leaves celebration as the last callback',
      (tester) async {
    storage.values['study_session:study'] = {
      'durationMilliseconds': 1,
      'elapsedMilliseconds': 0,
      'goal': '读书',
      'phase': 'focusing',
    };
    await mount(tester);
    await tester.tap(find.text('继续学习'));
    await tester.pump();
    // Advance wall time only. The periodic fake timer must not fire: tapping
    // pause itself discovers the expired countdown and synchronously completes.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(spoken, isEmpty);
    callbackOrder.clear();
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(spoken, hasLength(1));
    expect(callbackOrder.first, 'quiet:false');
    expect(callbackOrder.where((event) => event == 'celebrate'), hasLength(1));
    expect(callbackOrder.last, 'celebrate',
        reason: 'A quiet reset after celebration cancels completion speech.');
    await tester.pumpWidget(const SizedBox());
  });
}
