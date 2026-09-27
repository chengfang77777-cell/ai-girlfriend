import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/tts_service.dart';

Uint8List sampleWav(int marker) {
  final bytes = Uint8List(48);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  bytes.setRange(36, 40, ascii.encode('data'));
  final data = ByteData.sublistView(bytes);
  data.setUint32(4, 40, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, 4, Endian.little);
  bytes[44] = marker;
  return bytes;
}

http.Response audioResponse(Uint8List bytes) => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'audio': {'data': base64Encode(bytes)}
          }
        }
      ]
    }),
    200);

class OwnedMockClient extends MockClient {
  OwnedMockClient(super.handler, {this.onClose});
  final void Function()? onClose;
  bool closed = false;
  @override
  void close() {
    if (!closed) {
      closed = true;
      onClose?.call();
    }
    super.close();
  }
}

void main() {
  test(
      'one transient network failure reconnects automatically without changing request',
      () async {
    final requests = <String>[];
    var made = 0, retries = 0;
    final clients = <OwnedMockClient>[];
    final service = TtsService(clientFactory: () async {
      final index = made++;
      final client = OwnedMockClient((request) async {
        requests.add(request.body);
        if (index == 0) throw http.ClientException('connection reset');
        return audioResponse(sampleWav(3));
      });
      clients.add(client);
      return client;
    })
      ..apiKeyOverride = 'test-key';
    service.onConnectionRetry = () {
      retries++;
    };
    expect(await service.speak('你好'), isNotNull);
    expect(made, 2);
    expect(retries, 1);
    expect(requests[0], requests[1]);
    expect(clients.every((c) => c.closed), true);
  });
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('stable_voice_test_');
    Hive.init(directory.path);
    await StorageService().init();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('timed-out transport is closed and retry uses a fresh client', () async {
    final pending = Completer<http.Response>();
    final old = OwnedMockClient((_) => pending.future, onClose: () {
      if (!pending.isCompleted) {
        pending.completeError(http.ClientException('closed'));
      }
    });
    final next = OwnedMockClient((_) async => audioResponse(sampleWav(2)));
    var created = 0;
    final service = TtsService(
        clientFactory: () async => created++ == 0 ? old : next,
        connectionRetries: 0,
        requestTimeout: const Duration(milliseconds: 20))
      ..apiKeyOverride = 'test-key';
    await expectLater(service.speak('你好'), throwsA(isA<TtsException>()));
    expect(old.closed, true);
    expect(await service.speak('重试'), isNotNull);
    expect(created, 2);
    expect(next.closed, true);
  });

  test(
      'stop aborts the active transport instead of leaving a network request running',
      () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = OwnedMockClient((_) {
      started.complete();
      return pending.future;
    }, onClose: () {
      if (!pending.isCompleted) {
        pending.completeError(http.ClientException('closed'));
      }
    });
    final service = TtsService(clientFactory: () async => client)
      ..apiKeyOverride = 'test-key';
    final result =
        expectLater(service.speak('你好'), throwsA(isA<TtsException>()));
    await started.future;
    service.stop();
    await result;
    expect(client.closed, true);
  });

  test('a stalled service returns a specific bounded timeout', () async {
    final release = Completer<http.Response>();
    final client = MockClient((_) => release.future);
    final service = TtsService(
        client: client,
        connectionRetries: 0,
        requestTimeout: const Duration(milliseconds: 20))
      ..apiKeyOverride = 'test-key';
    await expectLater(
        service.speak('你好'),
        throwsA(isA<TtsException>()
            .having((e) => e.message, 'message', contains('超时'))));
    release.complete(audioResponse(sampleWav(1)));
    client.close();
  });

  test(
      'reference survives a storage reopen and stays isolated per character and description',
      () async {
    final requests = <Map<String, dynamic>>[];
    var referenceCount = 0;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      if (body['model'] == 'mimo-v2.5-tts-voicedesign') {
        return audioResponse(sampleWav(++referenceCount));
      }
      expect(body['model'], 'mimo-v2.5-tts-voiceclone');
      expect(body['audio']['voice'], startsWith('data:audio/wav;base64,'));
      return audioResponse(sampleWav(99));
    });
    TtsService service() =>
        TtsService(client: client)..apiKeyOverride = 'test-key';
    await service().speakWithStableVoice('第一句话',
        characterId: 'role-a', voiceDescription: '温柔女声');
    expect(requests, hasLength(1), reason: '首次回复只应合成一次');
    final firstReference =
        'data:audio/wav;base64,${base64Encode(sampleWav(1))}';
    expect(referenceCount, 1);
    expect(requests.last['messages'].last['content'], '第一句话');
    await Hive.close();
    await StorageService().init();
    await service().speakWithStableVoice('第二句话',
        characterId: 'role-a', voiceDescription: '温柔女声');
    expect(referenceCount, 1);
    expect(requests.last['audio']['voice'], firstReference);
    await service().speakWithStableVoice('另一位角色',
        characterId: 'role-b', voiceDescription: '温柔女声');
    expect(referenceCount, 2);
    expect(requests.last['audio']['voice'], isNot(firstReference));
    await service().speakWithStableVoice('修改音色',
        characterId: 'role-a', voiceDescription: '清冷女声');
    expect(referenceCount, 3);
    expect(requests.last['audio']['voice'], isNot(firstReference));
    client.close();
  });

  test(
      'clone failure preserves the reference and never falls back to a new voice',
      () async {
    var designs = 0;
    var failClone = false;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      if (body['model'] == 'mimo-v2.5-tts-voicedesign') {
        designs++;
        return audioResponse(sampleWav(10));
      }
      return failClone
          ? http.Response('unavailable', 503)
          : audioResponse(sampleWav(99));
    });
    final service = TtsService(client: client)..apiKeyOverride = 'test-key';
    await service.speakWithStableVoice('你好',
        characterId: 'failure-role', voiceDescription: '柔和');
    failClone = true;
    await expectLater(
        service.speakWithStableVoice('再见',
            characterId: 'failure-role', voiceDescription: '柔和'),
        throwsA(isA<TtsException>()));
    expect(designs, 1);
    failClone = false;
    expect(
        await service.speakWithStableVoice('重试',
            characterId: 'failure-role', voiceDescription: '柔和'),
        isNotNull);
    expect(designs, 1);
    client.close();
  });

  test('concurrent first requests share one reference generation', () async {
    var designs = 0;
    final release = Completer<void>();
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      if (body['model'] == 'mimo-v2.5-tts-voicedesign') {
        designs++;
        await release.future;
      }
      return audioResponse(sampleWav(11));
    });
    final service = TtsService(client: client)..apiKeyOverride = 'test-key';
    final a = service.speakWithStableVoice('一',
        characterId: 'concurrent-role', voiceDescription: '清亮');
    final b = service.speakWithStableVoice('二',
        characterId: 'concurrent-role', voiceDescription: '清亮');
    await Future<void>.delayed(Duration.zero);
    release.complete();
    final results = await Future.wait([a, b]);
    expect(results.every((result) => result != null), isTrue);
    expect(designs, 1);
    client.close();
  });

  test('invalid reference audio is not saved or sent to the clone endpoint',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return audioResponse(Uint8List.fromList([1, 2, 3]));
    });
    final service = TtsService(client: client)..apiKeyOverride = 'test-key';
    expect(
        await service.speakWithStableVoice('你好',
            characterId: 'invalid-role', voiceDescription: '温柔'),
        isNull);
    expect(calls, 1);
    expect(
        StorageService()
            .getSetting<dynamic>('tts_voice_reference_v1:invalid-role'),
        isNull);
    client.close();
  });
}
