import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tts_service_web.dart';
import 'character_provider.dart';

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
final isPlayingProvider = StateProvider<bool>((ref) => false);

final autoPlayVoiceProvider = StateProvider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.autoPlayVoice;
});

class VoiceNotifier extends StateNotifier<bool> {
  final TtsService _tts;

  VoiceNotifier(this._tts) : super(false);

  Future<void> speak(
    String text, {
    String? voice,
    String? voiceDescription,
  }) async {
    state = true;
    try {
      Uint8List? bytes;

      // 如果有音色描述，使用 voice design 模型
      if (voiceDescription != null && voiceDescription.isNotEmpty) {
        bytes = await _tts.speakWithVoiceDesign(
          text,
          voiceDescription: voiceDescription,
        );
      } else {
        // 否则使用预设音色
        bytes = await _tts.speak(text, voice: voice ?? '冰糖');
      }

      // For web, we don't need to play audio from bytes
      // The TTS service handles playback via Web Speech API
      state = false;
    } catch (e) {
      state = false;
    }
  }

  void stop() {
    _tts.stop();
    state = false;
  }
}

final voiceNotifierProvider = StateNotifierProvider<VoiceNotifier, bool>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  return VoiceNotifier(tts);
});
