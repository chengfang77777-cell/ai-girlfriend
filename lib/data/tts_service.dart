import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/secrets.dart';
import 'storage_service.dart';
import 'speech_http_client.dart';

class TtsException implements Exception {
  const TtsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// MiMo speech synthesis with a persistent reference voice per character.
class TtsService {
  TtsService(
      {http.Client? client,
      Future<http.Client> Function()? clientFactory,
      this.requestTimeout = const Duration(seconds: 30),
      this.connectionRetries = 1})
      : _client = client,
        _clientFactory = clientFactory ?? createSpeechHttpClient;
  final Duration requestTimeout;
  final int connectionRetries;
  void Function()? onConnectionRetry;

  final http.Client? _client;
  final Future<http.Client> Function() _clientFactory;
  final Set<http.Client> _activeClients = {};
  int _cancelGeneration = 0;
  final Map<String, Future<({Uint8List audio, String? text})?>>
      _pendingReferences = {};
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  String? apiKeyOverride;

  static const _endpoint = 'https://api.xiaomimimo.com/v1/chat/completions';

  String get _apiKey {
    final override = apiKeyOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    try {
      final saved = StorageService().mimoApiKey?.trim() ?? '';
      if (saved.isNotEmpty) return saved;
    } catch (error) {
      debugPrint('TTS: stored key is not available: $error');
    }
    return Secrets.mimoApiKey;
  }

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<Uint8List?> speak(String text, {String voice = '冰糖'}) =>
      _synthesize(text, model: 'mimo-v2.5-tts', voice: voice);

  Future<Uint8List?> speakWithVoiceDesign(
    String text, {
    required String voiceDescription,
  }) =>
      _synthesize(text,
          model: 'mimo-v2.5-tts-voicedesign', instruction: voiceDescription);

  /// Design once, persist the original reference, and clone it for every reply.
  /// A failed clone deliberately does not switch back to a newly designed voice.
  Future<Uint8List?> speakWithStableVoice(
    String text, {
    required String characterId,
    required String voiceDescription,
  }) async {
    if (text.trim().isEmpty || characterId.trim().isEmpty) return null;
    if (!hasApiKey) throw const TtsException('请在设置中填写 MiMo API Key');
    final description = voiceDescription.trim();
    if (description.isEmpty) return null;
    _isPlaying = true;
    final pendingKey = jsonEncode([characterId, description]);
    try {
      final pending = _pendingReferences.putIfAbsent(pendingKey,
          () => _loadOrCreateReference(characterId, description, text));
      ({Uint8List audio, String? text})? reference;
      try {
        reference = await pending;
      } finally {
        if (identical(_pendingReferences[pendingKey], pending)) {
          _pendingReferences.remove(pendingKey);
        }
      }
      if (reference == null) return null;
      // The first real reply is both the audible answer and the fixed sample.
      // Reusing it avoids a second sequential synthesis before first playback.
      if (reference.text == text) return reference.audio;
      return await _synthesize(
        text,
        model: 'mimo-v2.5-tts-voiceclone',
        voice: 'data:audio/wav;base64,${base64Encode(reference.audio)}',
        instruction: '保持参考音频中同一位说话者的音色、声线和口音，用自然的语气朗读。',
      );
    } catch (error) {
      if (error is TtsException) rethrow;
      throw const TtsException('固定音色读取或保存失败，请重试');
    } finally {
      _isPlaying = false;
    }
  }

  Future<({Uint8List audio, String? text})?> _loadOrCreateReference(
      String characterId, String description, String text) async {
    final storage = StorageService();
    final key = 'tts_voice_reference_v1:$characterId';
    final stored = storage.getSetting<dynamic>(key);
    if (stored is Map &&
        stored['description'] == description &&
        stored['version'] == 1) {
      final audio = stored['audio'];
      if (audio is Uint8List && _isValidReference(audio)) {
        return (audio: audio, text: null);
      }
    }
    final reference =
        await speakWithVoiceDesign(text, voiceDescription: description);
    if (reference == null || !_isValidReference(reference)) {
      debugPrint('TTS: reference generation returned no usable WAV');
      return null;
    }
    // Store only the original reference, never a cloned reply (avoids drift).
    await storage.setSetting(key, {
      'version': 1,
      'description': description,
      'audio': reference,
    });
    // Ensure the chosen voice survives an application restart.
    await storage.settingsBox.flush();
    return (audio: reference, text: text);
  }

  static bool _isValidReference(Uint8List bytes) {
    // MiMo limits the base64 sample to 10 MB. Keep some room below that limit.
    if (bytes.length < 44 || bytes.length > 7000000) return false;
    if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      return false;
    }
    final data = ByteData.sublistView(bytes);
    for (var offset = 12; offset + 8 <= bytes.length;) {
      final length = data.getUint32(offset + 4, Endian.little);
      if (offset + 8 + length > bytes.length) return false;
      final chunk =
          ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
      if (chunk == 'data') return length > 0;
      offset += 8 + length + (length % 2);
    }
    return false;
  }

  Future<Uint8List?> _synthesize(
    String text, {
    required String model,
    String? voice,
    String? instruction,
  }) async {
    if (text.trim().isEmpty) return null;
    final apiKey = _apiKey;
    if (apiKey.isEmpty) throw const TtsException('请在设置中填写 MiMo API Key');
    _isPlaying = true;
    final watch = Stopwatch()..start();
    final generation = _cancelGeneration;
    try {
      final body = jsonEncode({
        'model': model,
        'messages': [
          if (instruction != null && instruction.isNotEmpty)
            {'role': 'user', 'content': instruction},
          {'role': 'assistant', 'content': text},
        ],
        'audio': {'format': 'wav', if (voice != null) 'voice': voice},
      });
      final headers = {'Content-Type': 'application/json', 'api-key': apiKey};
      final uri = Uri.parse(_endpoint);
      final response = await _post(uri, headers, body, generation);
      if (generation != _cancelGeneration) throw const TtsException('语音请求已取消');
      if (response.statusCode != 200) {
        debugPrint('TTS: $model returned HTTP ${response.statusCode}');
        final code = response.statusCode;
        throw TtsException(code == 401 || code == 403
            ? '语音认证失败，请检查 MiMo API Key'
            : code == 429
                ? '语音服务繁忙或额度不足，请稍后重试'
                : '语音服务返回错误（$code），请重试');
      }
      final data = jsonDecode(response.body);
      final encoded =
          data['choices']?[0]?['message']?['audio']?['data'] as String?;
      if (encoded == null) return null;
      final bytes = base64Decode(encoded);
      return bytes.isEmpty ? null : bytes;
    } catch (error) {
      if (error is TtsException) rethrow;
      if (error is TimeoutException) throw const TtsException('语音生成超时，请重试');
      throw const TtsException('语音连接异常或音频数据无效，请重试');
    } finally {
      debugPrint('TTS: $model finished in ${watch.elapsedMilliseconds} ms');
      _isPlaying = false;
    }
  }

  Future<http.Response> _post(
      Uri uri, Map<String, String> headers, String body, int generation) async {
    for (var attempt = 0;; attempt++) {
      http.Client? transport;
      final ownsClient = _client == null;
      try {
        if (generation != _cancelGeneration) {
          throw const TtsException('语音请求已取消');
        }
        transport = _client ?? await _clientFactory();
        if (generation != _cancelGeneration) {
          throw const TtsException('语音请求已取消');
        }
        if (ownsClient) _activeClients.add(transport);
        return await transport
            .post(uri, headers: headers, body: body)
            .timeout(requestTimeout);
      } catch (error) {
        final transient =
            error is TimeoutException || error is http.ClientException;
        if (generation != _cancelGeneration ||
            !transient ||
            attempt >= connectionRetries) rethrow;
        onConnectionRetry?.call();
      } finally {
        // A timeout must close the socket before retry, not leave work running.
        if (ownsClient && transport != null) {
          _activeClients.remove(transport);
          transport.close();
        }
      }
    }
  }

  void stop() {
    ++_cancelGeneration;
    onConnectionRetry = null;
    _pendingReferences.clear();
    for (final client in _activeClients.toList()) {
      client.close();
    }
    _activeClients.clear();
    _isPlaying = false;
  }
}
