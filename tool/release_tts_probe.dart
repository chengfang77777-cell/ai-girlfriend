import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/data/tts_service.dart';
import 'package:ai_girlfriend/data/speech_http_client.dart';

/// Temporary release-runtime diagnostic entrypoint. No real app data is changed.
Future<void> runReleaseTtsProbe() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final temporary = await Directory.systemTemp.createTemp('release_tts_probe_');
  final output = File('${docs.path}/tts-release-probe.log');
  Future<void> log(String message) async {
    await output.writeAsString('$message\n',
        mode: FileMode.append, flush: true);
  }

  await output.writeAsString('release runtime probe\n');
  var failed = false;
  try {
    for (final box in ['settings', 'characters']) {
      final source = File('${docs.path}/$box.hive');
      if (await source.exists()) {
        await source.copy('${temporary.path}/$box.hive');
      }
    }
    Hive.init(temporary.path);
    final storage = StorageService();
    await storage.init();
    final id = storage.currentCharacterId;
    final role = id == null ? null : storage.getCharacter(id);
    if (role == null) {
      await log('No selected role');
      failed = true;
      return;
    }
    final config = await WindowsSpeechProxy.read();
    await log(
        'systemProxy enabled=${config.enabled} decision=${config.findProxy(Uri.parse("https://api.xiaomimimo.com"))}');
    final service = TtsService(
        clientFactory: () async => ProbeClient(
            await createSpeechHttpClient(), log, storage.mimoApiKey ?? ''),
        requestTimeout: const Duration(seconds: 90),
        connectionRetries: 0);
    for (var trial = 1; trial <= 1; trial++) {
      final clock = Stopwatch()..start();
      await log('request_start trial=$trial role=$id');
      try {
        final bytes = await service.speakWithStableVoice('今天也辛苦啦，坐下来休息一会儿吧。',
            characterId: role.id,
            voiceDescription: role.voiceDescription ?? '自然温柔的女性声音');
        await log(
            'request_end trial=$trial elapsedMs=${clock.elapsedMilliseconds} bytes=${bytes?.length}');
        if (bytes == null || bytes.isEmpty) failed = true;
      } catch (e) {
        failed = true;
        await log(
            'request_error trial=$trial elapsedMs=${clock.elapsedMilliseconds} error=$e');
      }
    }
  } finally {
    await Hive.close();
    await temporary.delete(recursive: true);
    exit(failed ? 1 : 0);
  }
}

void main() {
  runReleaseTtsProbe();
}

class ProbeClient extends http.BaseClient {
  ProbeClient(this.inner, this.log, this.key);
  final http.Client inner;
  final Future<void> Function(String) log;
  final String key;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final clock = Stopwatch()..start();
    final response = await inner.send(request);
    await log(
        'response_headers status=${response.statusCode} elapsedMs=${clock.elapsedMilliseconds} retryAfter=${response.headers['retry-after']}');
    if (response.statusCode < 400) return response;
    final bytes = await response.stream.toBytes();
    try {
      final data = jsonDecode(utf8.decode(bytes));
      final error = data is Map ? data['error'] : null;
      if (error is Map) {
        for (final field in ['code', 'type', 'message']) {
          var value = error[field]?.toString() ?? '';
          if (key.isNotEmpty) value = value.replaceAll(key, '[redacted]');
          await log(
              'error_$field: ${value.length > 400 ? value.substring(0, 400) : value}');
        }
      }
    } catch (_) {
      await log('non-JSON error body');
    }
    return http.StreamedResponse(Stream.value(bytes), response.statusCode,
        headers: response.headers);
  }

  @override
  void close() => inner.close();
}
