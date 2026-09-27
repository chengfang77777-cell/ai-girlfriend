import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/domain/audio_playback.dart';
import 'stable_voice_test.dart' show sampleWav;

void main() {
  test('duration uses WAV metadata, including 24 kHz PCM', () {
    final wav = Uint8List(48044)..setRange(0, 44, sampleWav(1));
    final data = ByteData.sublistView(wav);
    data.setUint32(4, 48036, Endian.little);
    data.setUint32(40, 48000, Endian.little);
    expect(AudioPlayback.wavDuration(wav), const Duration(seconds: 1));
    expect(AudioPlayback.wavDuration(Uint8List(44)), isNull);
  });
  testWidgets('missing startup reports failure instead of hanging',
      (tester) async {
    final player = AudioPlayback('one', sampleWav(1));
    final failed = expectLater(player.done, throwsStateError);
    await tester.pump(const Duration(seconds: 11));
    await failed;
  });
  testWidgets('stale events cannot finish new playback; real end can',
      (tester) async {
    var started = 0, ended = false;
    final player = AudioPlayback('new', sampleWav(1), onStarted: () {
      started++;
    });
    final done = player.done.then((_) {
      ended = true;
    });
    player.handle('audio_started:old');
    player.handle('audio_ended:old');
    await tester.pump();
    expect(ended, false);
    expect(started, 0);
    player.handle('audio_started:new');
    player.handle('audio_started:new');
    expect(started, 1);
    await tester.pump(const Duration(seconds: 11));
    expect(ended, false);
    player.handle('audio_ended:new');
    await done;
    expect(ended, true);
  });
  testWidgets('a stalled started player also times out', (tester) async {
    final player = AudioPlayback('stall', sampleWav(1));
    final failed = expectLater(player.done, throwsStateError);
    player.handle('audio_started:stall');
    await tester.pump(const Duration(seconds: 16));
    await failed;
  });
}
