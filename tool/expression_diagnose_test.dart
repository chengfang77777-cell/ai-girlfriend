import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:ai_girlfriend/core/constants.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/deepseek_api.dart';
import 'package:ai_girlfriend/data/llm_provider.dart';
import 'package:ai_girlfriend/data/speech_http_client.dart';

class FormatTraceClient extends http.BaseClient {
  FormatTraceClient(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    print('LLM status=${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(bytes));
      final content = data['choices'][0]['message']['content'] as String;
      final candidate = content.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      try {
        final parsed = jsonDecode(candidate) as Map;
        print(
            'raw structured=true emotion=${parsed['emotion']} action=${parsed['action']}');
      } catch (_) {
        print(
            'raw structured=false chars=${content.length} hasEmotionField=${content.contains('"emotion"')}');
      }
    }
    return http.StreamedResponse(Stream.value(bytes), response.statusCode,
        headers: response.headers);
  }

  @override
  void close() => inner.close();
}

void main() {
  test('diagnose reply format using isolated data', () async {
    const path = String.fromEnvironment('DATA_PATH');
    final temp = await Directory.systemTemp.createTemp('expression_probe_');
    for (final box in ['settings', 'characters', 'messages']) {
      await File('$path/$box.hive').copy('${temp.path}/$box.hive');
    }
    Hive.init(temp.path);
    try {
      final storage = StorageService();
      await storage.init();
      final role = storage.getCharacter(storage.currentCharacterId!)!;
      final history = storage.getMessages(role.id);
      final provider = LlmProvider.fromId(
          storage.getSetting<String>(AppConstants.llmProviderKey));
      print('provider=${provider.id} historyCount=${history.length}');
      for (final reply
          in history.where((m) => m.isAssistant).toList().reversed.take(12)) {
        // Only relevant acting cues, never full private conversations or API keys.
        final cues =
            RegExp(r'[（(][^）)]{1,10}[）)]|开心|难过|生气|害羞|惊讶|谢谢|笑|哭|不满|高兴|吓|委屈')
                .allMatches(reply.content)
                .map((m) => m.group(0))
                .toList();
        print(
            'saved emotion=${reply.emotion} action=${reply.action} cues=$cues');
      }
      if (const bool.fromEnvironment('LIVE')) {
        final key = provider.id == 'mimo' ? storage.mimoApiKey : storage.apiKey;
        final api = DeepSeekApi(
            apiKey: key!,
            provider: provider,
            client: FormatTraceClient(await createSpeechHttpClient()),
            maxRetries: 1);
        try {
          final result = await api.sendMessage(
              character: role,
              history: history,
              userMessage: '我今天考试考了第一名，特别开心，你也为我高兴一下吧！');
          print(
              'parsed emotion=${result['emotion']} action=${result['action']}');
        } finally {
          api.dispose();
        }
      }
    } finally {
      await Hive.close();
      await temp.delete(recursive: true);
    }
  },
      skip: const String.fromEnvironment('DATA_PATH').isEmpty,
      timeout: const Timeout(Duration(minutes: 2)));
}
