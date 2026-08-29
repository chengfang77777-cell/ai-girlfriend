import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/tts_service.dart';
import 'character_provider.dart';

/// Callback signature for sending audio bytes to the VRM viewer's lip-sync engine.
/// Implemented by home_page.dart (which owns the WebViewController).
typedef LipSyncAudioSender = void Function(Uint8List wavBytes);

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
final isPlayingProvider = StateProvider<bool>((ref) => false);

final autoPlayVoiceProvider = StateProvider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.autoPlayVoice;
});

class VoiceNotifier extends StateNotifier<bool> {
  final TtsService _tts;
  Timer? _stateResetTimer;

  /// Set by home_page.dart to forward audio to the VRM viewer for lip-sync.
  /// When null, lip-sync is skipped (e.g. on platforms without WebView).
  LipSyncAudioSender? lipSyncSender;

  /// TTS 合成失败/异常时的回调（由 home_page 设置，用于向用户弹出提示）
  void Function(String message)? onTtsError;

  VoiceNotifier(this._tts) : super(false);

  Future<void> speak(
    String text, {
    String? voice,
    String? voiceDescription,
  }) async {
    // 取消上一次未完成的计时器，避免多个计时器叠加导致状态被提前复位
    _stateResetTimer?.cancel();
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

      if (bytes != null && bytes.isNotEmpty) {
        // ⭐ Forward to VRM viewer for lip-sync AND audio playback
        // The viewer handles both audio output and lip-sync analysis in sync
        _sendToLipSync(bytes);

        // Don't use Flutter's AudioPlayer — the WebView plays the audio
        // via AudioContext, which is synchronized with the lip-sync analysis.
        // Just track state with a timer based on audio duration.
        // Estimate duration based on WAV size (16-bit mono 16kHz = 32000 bytes/sec)
        final estimatedDur = Duration(milliseconds: max(2000, bytes.length * 1000 ~/ 32000));
        _stateResetTimer = Timer(estimatedDur, () {
          state = false;
        });
      } else {
        state = false;
        onTtsError?.call('语音合成失败，请检查网络或 MiMo API Key');
      }
    } catch (e) {
      state = false;
      onTtsError?.call('语音合成异常，请稍后重试');
    }
  }

  /// Send WAV bytes to the VRM viewer's lip-sync engine.
  /// Writes the WAV to the vrm directory (served by the shelf server at port 127.0.0.1)
  /// then tells the viewer via executeScript to play from that URL.
  void _sendToLipSync(Uint8List bytes) {
    final sender = lipSyncSender;
    if (sender == null) return;
    try {
      Future.microtask(() => sender(bytes));
    } catch (e) {
      debugPrint('[VoiceNotifier] lipSyncSender error: $e');
    }
  }

  Future<String> _writeTemp(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    await file.writeAsBytes(bytes);
    return file.path;
  }


  void stop() {
    _tts.stop();
    _stateResetTimer?.cancel();
    _stateResetTimer = null;
    state = false;
  }
}

final voiceNotifierProvider = StateNotifierProvider<VoiceNotifier, bool>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  return VoiceNotifier(tts);
});

/// Provider for the lip-sync audio sender callback.
/// home_page.dart overrides this when a WebViewController is available.
final lipSyncAudioSenderProvider = StateProvider<LipSyncAudioSender?>((ref) => null);
