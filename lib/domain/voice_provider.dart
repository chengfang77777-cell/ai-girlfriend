import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tts_service.dart';
import 'character_provider.dart';

/// Callback signature for sending audio bytes to the VRM viewer's lip-sync engine.
/// Implemented by home_page.dart (which owns the WebViewController).
typedef LipSyncAudioSender = Future<void> Function(Uint8List wavBytes);

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
final voiceStatusProvider = StateProvider<String?>((ref) => null);
final isPlayingProvider = StateProvider<bool>((ref) => false);

final autoPlayVoiceProvider = StateProvider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.autoPlayVoice;
});

class VoiceNotifier extends StateNotifier<bool> {
  final TtsService _tts;
  Future<void> Function()? stopPlayback;
  void Function(String? message)? onStatus;
  Future<void> Function()? _retry;
  Future<void> retry() async {
    await _retry?.call();
  }

  int _speechGeneration = 0;

  /// Set by home_page.dart to forward audio to the VRM viewer for lip-sync.
  /// Completes on playback end and propagates errors to the UI.
  LipSyncAudioSender? lipSyncSender;

  /// TTS 合成失败/异常时的回调（由 home_page 设置，用于向用户弹出提示）
  void Function(String message)? onTtsError;

  VoiceNotifier(this._tts) : super(false);

  Future<void> speak(
    String text, {
    String? characterId,
    String? voice,
    String? voiceDescription,
  }) async {
    // Invalidate older requests before any asynchronous work.
    final generation = ++_speechGeneration;
    _tts.stop();
    _tts.onConnectionRetry = () {
      if (generation == _speechGeneration) onStatus?.call('语音连接较慢，正在重新连接…');
    };
    _retry = () => speak(text,
        characterId: characterId,
        voice: voice,
        voiceDescription: voiceDescription);
    state = true;
    onStatus?.call('正在生成语音…');
    try {
      await stopPlayback?.call();
      if (generation != _speechGeneration) return;
      if (text.trim().isEmpty) throw StateError('这条消息没有可朗读的文字');
      Uint8List? bytes;

      if (voiceDescription != null && voiceDescription.trim().isNotEmpty) {
        bytes = characterId != null
            ? await _tts.speakWithStableVoice(
                text,
                characterId: characterId,
                voiceDescription: voiceDescription,
              )
            : await _tts.speakWithVoiceDesign(
                text,
                voiceDescription: voiceDescription,
              );
      } else {
        // 否则使用预设音色
        bytes = await _tts.speak(text, voice: voice ?? '冰糖');
      }

      // A previous role/request must never speak over the current character.
      if (generation != _speechGeneration) return;
      if (bytes != null && bytes.isNotEmpty) {
        final audio = bytes;
        _retry = () => _replay(audio);
        onStatus?.call('正在准备播放…');
        await _sendToLipSync(audio);
        if (generation != _speechGeneration) return;
        state = false;
      } else {
        state = false;
        onTtsError?.call('语音合成失败，请检查网络或 MiMo API Key');
      }
    } catch (e) {
      if (generation != _speechGeneration) return;
      state = false;
      onTtsError?.call(e is TtsException
          ? e.message
          : e is StateError
              ? e.message.toString()
              : '语音处理失败，请重试');
    } finally {
      if (generation == _speechGeneration) onStatus?.call(null);
    }
  }

  Future<void> _sendToLipSync(Uint8List bytes) async {
    final sender = lipSyncSender;
    if (sender == null) throw StateError('播放器尚未就绪，请等待角色加载后重试');
    await sender(bytes);
  }

  Future<void> _replay(Uint8List bytes) async {
    final generation = ++_speechGeneration;
    state = true;
    onStatus?.call('正在准备播放…');
    try {
      await stopPlayback?.call();
      if (generation != _speechGeneration) return;
      await _sendToLipSync(bytes);
    } catch (error) {
      if (generation == _speechGeneration) {
        onTtsError
            ?.call(error is StateError ? error.message.toString() : '播放失败，请重试');
      }
    } finally {
      if (generation == _speechGeneration) {
        state = false;
        onStatus?.call(null);
      }
    }
  }

  void stop() {
    _speechGeneration++;
    _tts.stop();
    _retry = null;
    onStatus?.call(null);
    state = false;
  }

  @override
  void dispose() {
    _speechGeneration++;
    _tts.stop();
    super.dispose();
  }
}

final voiceNotifierProvider = StateNotifierProvider<VoiceNotifier, bool>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  return VoiceNotifier(tts)
    ..onStatus = (message) {
      ref.read(voiceStatusProvider.notifier).state = message;
    };
});

/// Provider for the lip-sync audio sender callback.
/// home_page.dart overrides this when a WebViewController is available.
final lipSyncAudioSenderProvider =
    StateProvider<LipSyncAudioSender?>((ref) => null);
