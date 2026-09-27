import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/data/tts_service.dart';
import 'package:ai_girlfriend/domain/voice_provider.dart';

class ControlledTts extends TtsService {
  final calls = <String, Completer<Uint8List?>>{};
  @override
  Future<Uint8List?> speakWithStableVoice(
    String text, {
    required String characterId,
    required String voiceDescription,
  }) =>
      (calls[characterId] = Completer<Uint8List?>()).future;
}

void main() {
  test('async playback error is visible and retry reuses synthesized bytes',
      () async {
    final tts = ControlledTts();
    final notifier = VoiceNotifier(tts);
    final errors = <String>[];
    notifier.onTtsError = errors.add;
    var plays = 0;
    final finish = Completer<void>();
    notifier.lipSyncSender = (bytes) async {
      plays++;
      if (plays == 1) throw StateError('播放失败');
      await finish.future;
    };
    final speech =
        notifier.speak('你好', characterId: 'retry', voiceDescription: '温柔');
    await Future<void>.delayed(Duration.zero);
    tts.calls['retry']!.complete(Uint8List.fromList([1]));
    await speech;
    expect(errors, ['播放失败']);
    expect(notifier.state, false);
    final retry = notifier.retry();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, true);
    expect(plays, 2);
    expect(tts.calls['retry']!.isCompleted, true);
    finish.complete();
    await retry;
    expect(notifier.state, false);
    notifier.dispose();
  });
  test('missing playback bridge reports an error instead of silent success',
      () async {
    final tts = ControlledTts();
    final notifier = VoiceNotifier(tts);
    final errors = <String>[];
    notifier.onTtsError = errors.add;
    final pending =
        notifier.speak('你好', characterId: 'missing', voiceDescription: '温柔');
    await Future<void>.delayed(Duration.zero);
    tts.calls['missing']!.complete(Uint8List.fromList([1]));
    await pending;
    expect(errors, hasLength(1));
    expect(notifier.state, false);
    notifier.dispose();
  });
  test('role identity reaches stable TTS and only the latest request can play',
      () async {
    final tts = ControlledTts();
    final notifier = VoiceNotifier(tts);
    final played = <int>[];
    notifier.lipSyncSender = (bytes) async {
      played.add(bytes.first);
    };
    final old =
        notifier.speak('旧角色', characterId: 'old', voiceDescription: '温柔');
    await Future<void>.delayed(Duration.zero);
    final latest =
        notifier.speak('新角色', characterId: 'new', voiceDescription: '清冷');
    await Future<void>.delayed(Duration.zero);
    expect(tts.calls.keys, ['old', 'new']);
    tts.calls['new']!.complete(Uint8List.fromList([2]));
    await latest;
    tts.calls['old']!.complete(Uint8List.fromList([1]));
    await old;
    await Future<void>.delayed(Duration.zero);
    expect(played, [2]);
    notifier.dispose();
  });

  test('stopping or disposing cancels pending audio delivery', () async {
    for (final dispose in [false, true]) {
      final tts = ControlledTts();
      final notifier = VoiceNotifier(tts);
      final played = <Uint8List>[];
      notifier.lipSyncSender = (bytes) async {
        played.add(bytes);
      };
      final pending =
          notifier.speak('你好', characterId: 'role', voiceDescription: '温柔');
      await Future<void>.delayed(Duration.zero);
      if (dispose) {
        notifier.dispose();
      } else {
        notifier.stop();
      }
      tts.calls['role']!.complete(Uint8List.fromList([1]));
      await pending;
      await Future<void>.delayed(Duration.zero);
      expect(played, isEmpty);
      if (!dispose) notifier.dispose();
    }
  });
}
