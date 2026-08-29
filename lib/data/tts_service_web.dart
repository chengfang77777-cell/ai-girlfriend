import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../core/secrets.dart';
import 'storage_service.dart';

/// 小米 MiMo TTS — 网页版（使用 Web Speech API 作为备选）
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
      debugPrint('TTS: 未配置 MiMo API Key，回退到 Web Speech API');
      _speakWithWebSpeech(text);
      _isPlaying = false;
      return null;
    }
    _isPlaying = true;

    try {
      // Try MiMo TTS API first
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

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final audioBase64 = data['choices']?[0]?['message']?['audio']?['data'] as String?;
        if (audioBase64 != null) {
          final audioBytes = base64Decode(audioBase64);
          if (audioBytes.isNotEmpty) {
            debugPrint('TTS: ${audioBytes.length} bytes');
            _isPlaying = false;
            return audioBytes;
          }
        }
      }

      // Fallback to Web Speech API
      debugPrint('TTS: Using Web Speech API fallback');
      _speakWithWebSpeech(text);
      _isPlaying = false;
      return null;
    } catch (e) {
      // Fallback to Web Speech API
      debugPrint('TTS error: $e, using Web Speech API fallback');
      _speakWithWebSpeech(text);
      _isPlaying = false;
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
      debugPrint('TTS VoiceDesign: 未配置 MiMo API Key，回退到 Web Speech API');
      _speakWithWebSpeech(text);
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

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final audioBase64 = data['choices']?[0]?['message']?['audio']?['data'] as String?;
        if (audioBase64 != null) {
          final audioBytes = base64Decode(audioBase64);
          if (audioBytes.isNotEmpty) {
            debugPrint('TTS VoiceDesign: ${audioBytes.length} bytes');
            _isPlaying = false;
            return audioBytes;
          }
        }
      }

      // Fallback to Web Speech API
      debugPrint('TTS VoiceDesign: Using Web Speech API fallback');
      _speakWithWebSpeech(text);
      _isPlaying = false;
      return null;
    } catch (e) {
      // Fallback to Web Speech API
      debugPrint('TTS VoiceDesign error: $e, using Web Speech API fallback');
      _speakWithWebSpeech(text);
      _isPlaying = false;
      return null;
    }
  }

  void _speakWithWebSpeech(String text) {
    try {
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.lang = 'zh-CN';
      utterance.rate = 1.0;
      utterance.pitch = 1.0;
      utterance.volume = 1.0;

      // Try to find a Chinese voice
      final voices = html.window.speechSynthesis?.getVoices();
      if (voices != null) {
        for (final voice in voices) {
          if (voice.lang?.startsWith('zh') == true) {
            utterance.voice = voice;
            break;
          }
        }
      }

      html.window.speechSynthesis?.speak(utterance);
    } catch (e) {
      debugPrint('Web Speech API error: $e');
    }
  }

  void stop() {
    _isPlaying = false;
    try {
      html.window.speechSynthesis?.cancel();
    } catch (e) {
      debugPrint('Web Speech API stop error: $e');
    }
  }
}
