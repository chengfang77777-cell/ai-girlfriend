import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_girlfriend/data/speech_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/tts_service.dart';
import 'package:ai_girlfriend/domain/audio_playback.dart';

void main() {
  test('diagnose saved voice reference without changing application data',
      () async {
    final temp = await Directory.systemTemp.createTemp('tts_diagnose_');
    const source = String.fromEnvironment('TTS_DATA_PATH');
    for (final box in ['settings', 'characters', 'messages']) {
      final file = File('$source/$box.hive');
      if (await file.exists()) await file.copy('${temp.path}/$box.hive');
    }
    Hive.init(temp.path);
    try {
      final storage = StorageService();
      await storage.init();
      for (final key in storage.settingsBox.keys
          .where((k) => k.toString().startsWith('tts_voice_reference_v1:'))) {
        final reference = storage.settingsBox.get(key);
        final bytes = reference is Map ? reference['audio'] : null;
        print(
            'reference $key: bytes=${bytes is Uint8List ? bytes.length : 0}, durationMs=${bytes is Uint8List ? AudioPlayback.wavDuration(bytes)?.inMilliseconds : null}');
      }
      final id = storage.currentCharacterId;
      final character = id == null ? null : storage.getCharacter(id);
      print(
          'selected role: $id, descriptionChars=${character?.voiceDescription?.length}');
      if (id != null) {
        final replies =
            storage.getMessages(id).where((m) => m.isAssistant).toList();
        print('recent reply metadata: ${replies.reversed.take(12).map((m) => {
              'emotion': m.emotion,
              'action': m.action,
              'chars': m.content.length
            }).toList()}');
      }
      if (const bool.fromEnvironment('DIAG_LIVE') && character != null) {
        final tts = TtsService(
            clientFactory: () async => TraceClient(
                await createSpeechHttpClient(), storage.mimoApiKey ?? ''),
            requestTimeout: const Duration(seconds: 90),
            connectionRetries: 0);
        final clock = Stopwatch()..start();
        try {
          final bytes = await tts.speakWithStableVoice('你好，我在这里。今天有什么想和我聊聊的吗？',
              characterId: character.id,
              voiceDescription: character.voiceDescription ?? '自然温柔的女性声音');
          print(
              'saved-reference live: ${clock.elapsedMilliseconds} ms, bytes=${bytes?.length}');
          expect(bytes, isNotNull);
        } catch (e) {
          print('saved-reference live: ${clock.elapsedMilliseconds} ms, $e');
          rethrow;
        }
      }
    } finally {
      await Hive.close();
      await temp.delete(recursive: true);
    }
  },
      skip: const String.fromEnvironment('TTS_DATA_PATH').isEmpty,
      timeout: const Timeout(Duration(minutes: 2)));
}

class TraceClient extends http.BaseClient {
  TraceClient(this.inner, this.key);
  final http.Client inner;
  final String key;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final clock = Stopwatch()..start();
    final response = await inner.send(request);
    print(
        'response headers: status=${response.statusCode} elapsedMs=${clock.elapsedMilliseconds} retryAfter=${response.headers['retry-after']}');
    if (response.statusCode >= 400) {
      final bytes = await response.stream.toBytes();
      try {
        final data = jsonDecode(utf8.decode(bytes));
        final error = data is Map ? data['error'] : null;
        if (error is Map) {
          for (final field in ['code', 'type', 'message']) {
            var value = error[field]?.toString() ?? '';
            if (key.isNotEmpty) value = value.replaceAll(key, '[redacted]');
            print(
                'error $field: ${value.length > 400 ? value.substring(0, 400) : value}');
          }
        }
      } catch (_) {
        print('non-JSON error body');
      }
      return http.StreamedResponse(Stream.value(bytes), response.statusCode,
          headers: response.headers);
    }
    return response;
  }

  @override
  void close() => inner.close();
}
