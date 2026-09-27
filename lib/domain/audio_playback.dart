import 'dart:async';
import 'dart:typed_data';

/// A playback request ends only on a matching event or a bounded timeout.
class AudioPlayback {
  AudioPlayback(this.id, Uint8List wav,
      {this.onStarted, Duration startupTimeout = const Duration(seconds: 10)}) {
    _duration = wavDuration(wav) ?? const Duration(minutes: 3);
    _timer = Timer(startupTimeout, () => fail('播放器未能启动，请重试语音'));
  }
  final String id;
  final void Function()? onStarted;
  final _done = Completer<void>();
  late Duration _duration;
  Timer? _timer;
  bool _started = false;
  Future<void> get done => _done.future;

  void handle(String event) {
    if (_done.isCompleted) return;
    if (event == 'audio_started:$id' && !_started) {
      _started = true;
      _timer?.cancel();
      _timer = Timer(
          _duration + const Duration(seconds: 15), () => fail('语音播放中断，请重试'));
      onStarted?.call();
    } else if (event == 'audio_ended:$id' || event == 'audio_stopped:$id') {
      cancel();
    } else if (event.startsWith('audio_error:$id:')) {
      fail('音频加载或播放失败，请重试');
    }
  }

  void fail(String message) {
    if (_done.isCompleted) return;
    _timer?.cancel();
    _done.completeError(StateError(message));
  }

  void cancel() {
    _timer?.cancel();
    if (!_done.isCompleted) _done.complete();
  }

  static Duration? wavDuration(Uint8List bytes) {
    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.take(4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;
    final data = ByteData.sublistView(bytes);
    int? byteRate, dataSize;
    for (int pos = 12; pos + 8 <= bytes.length;) {
      final size = data.getUint32(pos + 4, Endian.little);
      if (pos + 8 + size > bytes.length) return null;
      final tag = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      if (tag == 'fmt ' && size >= 16) {
        byteRate = data.getUint32(pos + 16, Endian.little);
      }
      if (tag == 'data') dataSize = size;
      pos += 8 + size + size % 2;
    }
    if (byteRate == null || byteRate == 0 || dataSize == null) return null;
    return Duration(microseconds: dataSize * 1000000 ~/ byteRate);
  }
}
