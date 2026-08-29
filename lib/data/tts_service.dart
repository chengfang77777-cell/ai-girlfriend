import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/secrets.dart';
import 'storage_service.dart';

/// 小米 MiMo TTS — 高质量语音合成
class TtsService {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// 运行时注入的 Key（优先级最高），一般由设置页或调用方写入
  String? apiKeyOverride;

  static const _endpoint =
      'https://api.xiaomimimo.com/v1/chat/completions';

  /// 密钥解析顺序：运行时注入 > 设置页保存的用户 Key > secrets.dart 内置 Key
  String get _apiKey {
    final override = apiKeyOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;

    String saved = '';
    try {
      saved = StorageService().mimoApiKey?.trim() ?? '';
    } catch (e) {
      // StorageService 尚未初始化时忽略，回退到内置 Key
      debugPrint('TTS: read stored MiMo key failed: $e');
    }
    if (saved.isNotEmpty) return saved;

    return Secrets.mimoApiKey;
  }

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<Uint8List?> speak(String text, {String voice = '冰糖'}) async {
    if (text.trim().isEmpty) return null;
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      debugPrint('TTS: 未配置 MiMo API Key，请在设置页填写');
      _isPlaying = false;
      return null;
    }
    _isPlaying = true;

    try {
      // MiMo TTS API 请求格式
      final body = jsonEncode({
        'model': 'mimo-v2.5-tts',
        'messages': [
          {
            'role': 'assistant',
            'content': text,
          }
        ],
        'audio': {
          'format': 'wav',
          'voice': voice,
        }
      });

      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        debugPrint('TTS: HTTP ${resp.statusCode} - ${resp.body}');
        _isPlaying = false;
        return null;
      }

      final data = jsonDecode(resp.body);

      // 从响应中提取 base64 音频数据
      final audioBase64 = data['choices']?[0]?['message']?['audio']?['data'] as String?;
      if (audioBase64 == null) {
        debugPrint('TTS: no audio data in response');
        _isPlaying = false;
        return null;
      }

      // 解码 base64 音频
      final audioBytes = base64Decode(audioBase64);
      if (audioBytes.isNotEmpty) {
        debugPrint('TTS: ${audioBytes.length} bytes');
        _isPlaying = false;
        return audioBytes;
      }

      debugPrint('TTS: empty audio data');
      _isPlaying = false;
      return null;
    } catch (e) {
      _isPlaying = false;
      debugPrint('TTS error: $e');
      return null;
    }
  }

  /// 使用文本描述设计音色（自定义角色专用）
  Future<Uint8List?> speakWithVoiceDesign(
    String text, {
    required String voiceDescription,
  }) async {
    if (text.trim().isEmpty) return null;
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      debugPrint('TTS VoiceDesign: 未配置 MiMo API Key，请在设置页填写');
      _isPlaying = false;
      return null;
    }
    _isPlaying = true;

    try {
      // MiMo TTS Voice Design API 请求格式
      final body = jsonEncode({
        'model': 'mimo-v2.5-tts-voicedesign',
        'messages': [
          {
            'role': 'user',
            'content': voiceDescription,
          },
          {
            'role': 'assistant',
            'content': text,
          }
        ],
        'audio': {
          'format': 'wav',
        }
      });

      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        debugPrint('TTS VoiceDesign: HTTP ${resp.statusCode} - ${resp.body}');
        _isPlaying = false;
        return null;
      }

      final data = jsonDecode(resp.body);

      // 从响应中提取 base64 音频数据
      final audioBase64 = data['choices']?[0]?['message']?['audio']?['data'] as String?;
      if (audioBase64 == null) {
        debugPrint('TTS VoiceDesign: no audio data in response');
        _isPlaying = false;
        return null;
      }

      // 解码 base64 音频
      final audioBytes = base64Decode(audioBase64);
      if (audioBytes.isNotEmpty) {
        debugPrint('TTS VoiceDesign: ${audioBytes.length} bytes');
        _isPlaying = false;
        return audioBytes;
      }

      debugPrint('TTS VoiceDesign: empty audio data');
      _isPlaying = false;
      return null;
    } catch (e) {
      _isPlaying = false;
      debugPrint('TTS VoiceDesign error: $e');
      return null;
    }
  }

  void stop() {
    _isPlaying = false;
  }
}
