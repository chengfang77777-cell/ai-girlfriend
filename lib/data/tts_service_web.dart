import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;

/// 小米 MiMo TTS — 网页版（使用 Web Speech API 作为备选）
class TtsService {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  static const _apiKey = 'sk-ci32216m54mas4vqhphbs56ojaq5pfpcajpdp4bqi7e8q3ga';
  static const _endpoint =
      'https://api.xiaomimimo.com/v1/chat/completions';

  Future<Uint8List?> speak(String text, {String voice = '冰糖'}) async {
    if (text.trim().isEmpty) return null;
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
          'api-key': _apiKey,
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
          'api-key': _apiKey,
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
