import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/models/character.dart';
import 'package:ai_girlfriend/models/message.dart';
import 'package:ai_girlfriend/data/llm_provider.dart';
import 'package:ai_girlfriend/presentation/widgets/avatar_display.dart';

const character = Character(
    id: 'test',
    name: 'test',
    personalityTags: [],
    speakingStyle: '',
    avatarModelPath: '');

void main() {
  for (final provider in LlmProvider.all) {
    test('${provider.id} requests structured replies even after a long chat',
        () async {
      Map<String, dynamic>? requestBody;
      final api = DeepSeekApi(
          apiKey: 'test',
          provider: provider,
          client: MockClient((request) async {
            requestBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'content': jsonEncode({
                          'reply': '太棒了，真为你高兴！',
                          'emotion': 'happy',
                          'action': 'clap'
                        })
                      }
                    }
                  ]
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }));
      addTearDown(api.dispose);
      final result = await api.sendMessage(
          character: character,
          history: [
            Message(
                id: 'u',
                characterId: 'test',
                role: 'user',
                content: '你好',
                timestamp: DateTime(2026)),
            Message(
                id: 'a',
                characterId: 'test',
                role: 'assistant',
                content: '你好呀',
                emotion: 'neutral',
                action: 'greeting',
                timestamp: DateTime(2026)),
          ],
          userMessage: '我考了第一名！');
      expect(requestBody!['response_format'], {'type': 'json_object'});
      final messages = requestBody!['messages'] as List;
      expect(messages[1]['content'], '你好',
          reason: 'User text remains plain text');
      expect(jsonDecode(messages[2]['content'] as String),
          {'reply': '你好呀', 'emotion': 'neutral', 'action': 'greeting'},
          reason:
              'Assistant history must demonstrate the same structured output contract');
      expect(result['emotion'], 'happy');
      expect(result['reply'], '太棒了，真为你高兴！');
    });
  }
  test('avatar starts with a neutral expression', () {
    expect(const AvatarDisplay(characterName: 'test').currentEmotion,
        Emotion.neutral);
  });
  test('prompt permits neutral warmth and gives a neutral default example', () {
    final prompt = character.buildSystemPrompt();
    expect(prompt, isNot(contains('别老用 neutral')));
    expect(prompt, isNot(contains('就别填 neutral')));
    expect(prompt, isNot(contains('emotion 别无脑填 neutral')));
    expect(prompt, contains('"emotion": "neutral"'));
  });
  for (final reply in [
    '我没有笑，先说正事吧。',
    '爱好可以慢慢培养。',
    '我不开心，也笑不出来。',
    '我不喜欢这样，别开玩笑了。'
  ]) {
    test('respects neutral emotion for $reply', () async {
      final api = DeepSeekApi(
          apiKey: 'test',
          client: MockClient((request) async {
            return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'content': jsonEncode({
                          'reply': reply,
                          'emotion': 'neutral',
                          'action': 'talk'
                        })
                      }
                    }
                  ]
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }));
      final result = await api.sendMessage(
          character: character, history: [], userMessage: '聊聊吧');
      expect(result['emotion'], 'neutral');
    });
  }
  test('preserves an explicit happy reply', () async {
    final api = DeepSeekApi(
        apiKey: 'test',
        client: MockClient((request) async {
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'reply': '太好了！',
                        'emotion': 'happy',
                        'action': 'talk'
                      })
                    }
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    final result = await api.sendMessage(
        character: character, history: [], userMessage: '我成功了');
    expect(result['emotion'], 'happy');
  });
}
