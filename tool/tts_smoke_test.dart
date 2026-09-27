// Opt-in real backend check: flutter test tool/tts_smoke_test.dart
//   --dart-define=RUN_TTS_SMOKE=true
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/tts_service.dart';
import 'package:ai_girlfriend/domain/audio_playback.dart';

void main() {
  test('real design and fixed-reference clone produce playable WAV', () async {
    final temporary = await Directory.systemTemp.createTemp('tts_smoke_');
    const settingsPath = String.fromEnvironment('TTS_SETTINGS_PATH');
    if (settingsPath.isNotEmpty) {
      await File(settingsPath).copy('${temporary.path}/settings.hive');
    }
    Hive.init(temporary.path);
    try {
      await StorageService().init();
      final service = TtsService();
      expect(service.hasApiKey, true,
          reason: 'A locally configured key is required');
      final output = Directory('build/verification');
      await output.create(recursive: true);
      for (final entry in {
        'design': '你好，今天过得怎么样？我们可以慢慢聊聊，我会认真听你说。',
        'clone': '很高兴又见到你。现在声音和表情都会跟着我们的对话变化。',
      }.entries) {
        final watch = Stopwatch()..start();
        final bytes = await service.speakWithStableVoice(entry.value,
            characterId: 'smoke-only',
            voiceDescription: '温柔自然的成年女性声音，普通话清晰，语速适中');
        expect(bytes, isNotNull);
        final duration = AudioPlayback.wavDuration(bytes!);
        expect(duration, isNotNull);
        expect(duration!.inMilliseconds, greaterThan(500));
        await File('${output.path}/tts_${entry.key}.wav').writeAsBytes(bytes);
        // Deliberately log only timings and sizes, never keys or audio payloads.
        print(
            '${entry.key}: ${watch.elapsedMilliseconds} ms, ${bytes.length} bytes, ${duration.inMilliseconds} ms audio');
      }
    } finally {
      await Hive.close();
      await temporary.delete(recursive: true);
    }
  },
      skip: !const bool.fromEnvironment('RUN_TTS_SMOKE'),
      timeout: const Timeout(Duration(minutes: 2)));
}
