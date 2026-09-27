import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/character.dart';
import '../models/message.dart';
import 'llm_provider.dart';

/// OpenAI 兼容 Chat API 封装（默认 DeepSeek，可通过 [provider] 切换到小米 MiMo）
///
/// 架构设计要点：
/// 1. 连接池管理：复用HTTP客户端减少连接开销
/// 2. 请求超时控制：防止无限等待
/// 3. 滑动窗口上下文：自动管理历史消息数量
/// 4. 错误重试机制：指数退避策略
/// 5. JSON Mode：结构化响应解析
///
/// 提示词构建（system prompt、上下文窗口）与回复后处理（情绪/动作修正、
/// 括号清理、JSON 解析）对**所有供应商完全一致**，仅 baseUrl / 模型名 /
/// 认证头 / 生成长度参数名按 [provider] 差异化。
class DeepSeekApi {
  final String apiKey;

  /// 当前使用的模型供应商（默认 DeepSeek）
  final LlmProvider provider;

  final http.Client _client;
  final int _maxRetries;
  final Duration _baseTimeout;

  // 请求计数器用于监控
  int _requestCount = 0;
  int _errorCount = 0;
  DateTime _lastResetTime = DateTime.now();

  DeepSeekApi({
    required this.apiKey,
    this.provider = LlmProvider.deepseek,
    http.Client? client,
    int maxRetries = 3,
    Duration? baseTimeout,
  })  : _client = client ?? http.Client(),
        _maxRetries = maxRetries,
        _baseTimeout =
            baseTimeout ?? Duration(seconds: AppConstants.apiTimeout);

  /// 发送消息到AI，返回结构化回复
  Future<Map<String, String>> sendMessage({
    required Character character,
    required List<Message> history,
    required String userMessage,
  }) async {
    _validateInput(character, userMessage);
    _resetCounterIfNeeded();

    final url = Uri.parse(_buildApiUrl());
    final messages = _buildMessages(character, history, userMessage);
    final requestBody = _buildRequestBody(messages);

    Map<String, String> result;
    int attempt = 0;

    while (attempt < _maxRetries) {
      attempt++;
      try {
        result = await _executeRequest(url, requestBody, attempt);
        _requestCount++;
        // 后处理：限制括号动作描写数量，避免长篇大论式的动作戏
        result['reply'] = _limitBracketActions(result['reply'] ?? '');
        // 根据用户消息修正emotion（用户说难过时AI不应该开心）
        result['emotion'] = _correctEmotionWithContext(
            result['reply'] ?? '', result['emotion'] ?? 'neutral', userMessage);
        // 当AI没有显式给出具体动作时，根据语义推断身体动作
        result['action'] = _resolveAction(
            result['action'] ?? 'talk', result['reply'] ?? '', userMessage);
        return result;
      } on TimeoutException {
        _errorCount++;
        debugPrint('Request timeout (attempt $attempt/$_maxRetries)');
        if (attempt >= _maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2)); // 指数退避
      } on http.ClientException catch (e) {
        _errorCount++;
        debugPrint('HTTP client error: $e (attempt $attempt/$_maxRetries)');
        if (attempt >= _maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 3));
      } catch (e) {
        _errorCount++;
        debugPrint('Unexpected error: $e (attempt $attempt/$_maxRetries)');
        if (attempt >= _maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw Exception('All API attempts failed after $_maxRetries retries');
  }

  /// 限制回复中的括号动作描写：
  /// 1. 只保留第一处括号（后面的全部删掉）
  /// 2. 保留的那处若超过10个字（长篇动作/心理描写），也直接删掉
  String _limitBracketActions(String reply) {
    final bracketReg = RegExp(r'[（(][^）)]*[）)]');
    var count = 0;
    final result = reply.replaceAllMapped(bracketReg, (m) {
      count++;
      if (count > 1) return ''; // 只留第一处
      final inner = m.group(0)!;
      // 括号内容过长（去掉括号本身后超过10字）视为长篇描写，删除
      return (inner.length - 2) > 10 ? '' : inner;
    });
    // 清理删除括号后可能出现的多余空格
    return result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// 构建API URL（OpenAI 兼容路径，按供应商替换根地址）
  String _buildApiUrl() {
    return '${provider.baseUrl}/chat/completions';
  }

  /// 构建消息列表
  List<Map<String, dynamic>> _buildMessages(
    Character character,
    List<Message> history,
    String userMessage,
  ) {
    final messages = <Map<String, dynamic>>[];

    // System Prompt - 角色设定
    messages.add({
      'role': 'system',
      'content': character.buildSystemPrompt(),
    });

    // 滑动窗口：只保留最近N轮对话
    final recentHistory = history.length > AppConstants.contextWindowSize
        ? history.sublist(history.length - AppConstants.contextWindowSize)
        : history;

    // 添加历史消息
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.role == 'user' ? 'user' : 'assistant',
        // Plain assistant history teaches the model to omit the emotion/action
        // envelope on later turns, even when the system prompt asks for JSON.
        'content': msg.role == 'user'
            ? msg.content
            : jsonEncode({
                'reply': msg.content,
                'emotion': _correctEmotion(msg.content, msg.emotion),
                'action': _sanitizeAction(msg.action),
              }),
      });
    }

    // 当前用户消息
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    return messages;
  }

  /// 构建请求体（提示词内容对两家供应商完全一致）
  Map<String, dynamic> _buildRequestBody(List<Map<String, dynamic>> messages) {
    final body = <String, dynamic>{
      'model': provider.model,
      'messages': messages,
      'temperature': AppConstants.temperature,
      'response_format': {'type': 'json_object'},
    };
    // DeepSeek 使用 max_tokens；MiMo 官方示例使用 max_completion_tokens
    body[provider.useMaxCompletionTokens
        ? 'max_completion_tokens'
        : 'max_tokens'] = AppConstants.maxTokens;
    return body;
  }

  /// 执行HTTP请求
  Future<Map<String, String>> _executeRequest(
    Uri url,
    Map<String, dynamic> requestBody,
    int attempt,
  ) async {
    debugPrint(
        'AI Request (attempt $attempt): "${requestBody['messages'].last['content']}"');

    final response = await _client
        .post(
          url,
          headers: _buildHeaders(),
          body: jsonEncode(requestBody),
        )
        .timeout(_baseTimeout * (attempt == 1 ? 1 : 1.5)); // 重试时增加超时

    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    } else if (response.statusCode == 429) {
      // 速率限制，等待后重试
      await Future.delayed(Duration(seconds: attempt * 5));
      throw http.ClientException('Rate limited', url);
    } else if (response.statusCode == 401) {
      throw Exception('API认证失败，请检查API Key');
    } else if (response.statusCode >= 500) {
      throw http.ClientException('Server error: ${response.statusCode}', url);
    } else {
      throw Exception('API请求失败(${response.statusCode}): ${response.body}');
    }
  }

  /// 构建请求头
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AI-Girlfriend/1.0',
    };
    // DeepSeek：Authorization: Bearer；MiMo：api-key
    if (provider.useApiKeyHeader) {
      headers['api-key'] = apiKey;
    } else {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  /// 解析API响应
  /// 根据用户消息上下文修正emotion
  /// 用户说难过→AI不应该happy，用户说讨厌→AI应该angry
  String _correctEmotionWithContext(
      String reply, String emotion, String userMsg) {
    final user = userMsg.toLowerCase();
    final replyLower = reply.toLowerCase();

    // 用户表达负面情绪时，AI不应该开心
    if (user.contains('难过') ||
        user.contains('伤心') ||
        user.contains('哭') ||
        user.contains('烦') ||
        user.contains('累') ||
        user.contains('不好') ||
        user.contains('糟糕') ||
        user.contains('失望') ||
        user.contains('委屈')) {
      if (emotion == 'happy') {
        if (replyLower.contains('抱') ||
            replyLower.contains('心疼') ||
            replyLower.contains('陪') ||
            replyLower.contains('别难过') ||
            replyLower.contains('会好的')) return 'neutral';
        return 'sad';
      }
    }

    // 用户表达愤怒/讨厌时，AI不应该开心
    if (user.contains('生气') ||
        user.contains('愤怒') ||
        user.contains('烦死了') ||
        user.contains('气死') ||
        user.contains('讨厌') ||
        user.contains('恨') ||
        user.contains('滚') ||
        user.contains('闭嘴') ||
        user.contains('走开') ||
        user.contains('不理你') ||
        user.contains('不想理')) {
      if (emotion == 'happy' || emotion == 'shy') return 'angry';
    }

    // 先用文本分析修正neutral
    return _correctEmotion(reply, emotion);
  }

  /// 分析回复文本，修正emotion字段
  /// 当AI返回neutral但文本明显有情绪时，自动修正
  String _correctEmotion(String reply, String emotion) {
    // Respect the model's explicit neutral judgement. Individual words such as
    // 爱好、没有笑 or 不开心 do not imply a smiling facial expression.
    const allowed = {
      'happy',
      'shy',
      'angry',
      'sad',
      'surprised',
      'neutral',
      'refuse',
      'thankful'
    };
    final value = emotion.trim().toLowerCase();
    return allowed.contains(value) ? value : 'neutral';
  }

  /// 将AI返回的动作名收敛到受控词表，未知值一律回退为 'talk'（仅说话、不触发身体动作）
  String _sanitizeAction(String? action) {
    const allowed = {
      'talk',
      'happy',
      'sad',
      'angry',
      'refuse',
      'thankful',
      'clap',
      'clapping',
      'greeting',
      'shake_head',
      'yawn',
    };
    final a = (action ?? 'talk').trim().toLowerCase();
    return allowed.contains(a) ? a : 'talk';
  }

  /// 解析最终使用的 action：
  /// 若AI已给出具体动作（非 talk）则尊重AI；否则根据回复/用户语义推断。
  String _resolveAction(String raw, String reply, String userMsg) {
    final a = _sanitizeAction(raw);
    if (a != 'talk') return a;
    return _inferAction(reply, userMsg);
  }

  /// 判断用户是否在向 AI 道谢（而非感谢其他人/事物）。
  /// "谢谢/感谢"后紧跟"你/您" → 对 AI 道谢；
  /// "谢谢/感谢"在句尾或后跟语气词/标点 → 对 AI 道谢；
  /// 后面跟了其他人称、名字或事物（"谢谢小明""感谢大家"）→ 不是对 AI 道谢。
  bool _isThanksToAI(String text) {
    final toYou = RegExp(r'(谢谢|感谢)(你|您)');
    final atEnd = RegExp(r'(谢谢|感谢)(?=[啦呀哦啊呢哈吧嘛～~！!。.?？\s]|$)');
    return toYou.hasMatch(text) || atEnd.hasMatch(text);
  }

  /// 动作语义推断：当AI漏给 action 时，扫描文本关键词，让动作和语义对得上。
  /// 例如用户让AI感谢、或AI回复里出现"谢谢/你真好" → thankful；
  /// 出现"太棒了/为你鼓掌" → clap；"不要/不行/别嘛" → refuse 等。
  String _inferAction(String reply, String userMsg) {
    final r = reply.toLowerCase();
    final u = userMsg.toLowerCase();

    // 1) 用户明确要求的动作
    // 只有用户在向 AI 道谢时才触发（"谢谢你/谢谢啦/谢谢"），
    // 感谢其他人或事物（"谢谢小明""感谢大家"）不触发。
    if (_isThanksToAI(u) ||
        u.contains('道谢') ||
        u.contains('对我好一点') ||
        u.contains('谢谢我')) {
      return 'thankful';
    }
    if (u.contains('鼓掌') ||
        u.contains('为我骄傲') ||
        u.contains('夸我') ||
        u.contains('给我点赞')) {
      return 'clap';
    }
    if (u.contains('打招呼') ||
        u.contains('问好') ||
        u.contains('招手') ||
        u.contains('打个招呼')) {
      return 'greeting';
    }

    // 2) 根据AI回复语义推断
    if (r.contains('谢谢') ||
        r.contains('感谢') ||
        r.contains('你真好') ||
        r.contains('太感谢') ||
        r.contains('多亏你') ||
        r.contains('辛苦了') ||
        r.contains('感动')) {
      return 'thankful';
    }
    if (r.contains('太棒了') ||
        r.contains('厉害') ||
        r.contains('为你鼓掌') ||
        r.contains('真棒') ||
        r.contains('为你骄傲') ||
        r.contains('给你点赞') ||
        r.contains('鼓掌') ||
        r.contains('牛') ||
        r.contains('可以的')) {
      return 'clap';
    }
    if (r.contains('不要') ||
        r.contains('不行') ||
        r.contains('别嘛') ||
        r.contains('我才不') ||
        r.contains('不可以') ||
        r.contains('不要啦') ||
        r.contains('算了吧')) {
      return 'refuse';
    }
    if (r.contains('好久不见') ||
        r.contains('你好呀') ||
        r.contains('回来啦') ||
        r.contains('好久没见') ||
        r.contains('早上好') ||
        r.contains('晚上好')) {
      return 'greeting';
    }
    if (r.contains('生气') ||
        r.contains('愤怒') ||
        r.contains('烦死了') ||
        r.contains('讨厌死了') ||
        r.contains('你给我') ||
        r.contains('气死') ||
        r.contains('闭嘴') ||
        r.contains('真是够了') ||
        r.contains('讨打')) {
      return 'angry';
    }
    // 开心：笑声、撒娇、表达喜欢 → happy（播完保持 happy idle 循环）
    if (r.contains('哈哈') ||
        r.contains('嘻嘻') ||
        r.contains('嘿嘿') ||
        r.contains('开心') ||
        r.contains('太好了') ||
        r.contains('好耶') ||
        r.contains('耶！') ||
        r.contains('喜欢你') ||
        r.contains('爱你') ||
        r.contains('想你') ||
        r.contains('么么') ||
        r.contains('亲一') ||
        r.contains('甜') ||
        r.contains('期待')) {
      return 'happy';
    }
    // 难过：委屈、低落、心疼 → sad（播完保持 sad idle 循环）
    if (r.contains('难过') ||
        r.contains('伤心') ||
        r.contains('委屈') ||
        r.contains('呜呜') ||
        r.contains('哭') ||
        r.contains('心疼') ||
        r.contains('唉') ||
        r.contains('失落') ||
        r.contains('眼泪')) {
      return 'sad';
    }

    // 打哈欠：困倦、犯困、想睡、无聊发呆 → yawn
    if (r.contains('哈欠') ||
        r.contains('困') ||
        r.contains('好累') ||
        r.contains('犯困') ||
        r.contains('想睡') ||
        r.contains('瞌睡') ||
        r.contains('好困') ||
        r.contains('无聊') ||
        r.contains('发呆')) {
      return 'yawn';
    }

    // 3) 用户攻击性/惹恼的话，女友真生气（与 emotion=angry 一致）
    if (u.contains('滚') ||
        u.contains('闭嘴') ||
        u.contains('讨厌你') ||
        u.contains('烦死了') ||
        u.contains('气死') ||
        u.contains('走开') ||
        u.contains('不理你') ||
        u.contains('不想理') ||
        u.contains('你有病')) {
      return 'angry';
    }

    return 'talk';
  }

  Map<String, String> _parseResponse(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    // 验证响应结构
    if (!data.containsKey('choices') || (data['choices'] as List).isEmpty) {
      throw Exception('API返回了空响应');
    }

    var content = data['choices'][0]['message']['content'] as String;

    // Strip markdown code blocks (```json ... ```)
    content = content
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*$'), '')
        .replaceAll(RegExp(r'^```\s*'), '')
        .trim();

    // Try to extract JSON from the response
    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final reply = (parsed['reply'] as String?) ?? content;
      final emotion =
          _correctEmotion(reply, (parsed['emotion'] as String?) ?? 'neutral');
      return {
        'reply': reply,
        'emotion': emotion,
        'action': _sanitizeAction(parsed['action'] as String?),
      };
    } catch (_) {
      // Try to find a JSON object anywhere in the text
      final jsonMatch = RegExp(r'\{[^{}]*"reply"[^{}]*\}').firstMatch(content);
      if (jsonMatch != null) {
        try {
          final parsed =
              jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          final reply = (parsed['reply'] as String?) ?? content;
          final emotion = _correctEmotion(
              reply, (parsed['emotion'] as String?) ?? 'neutral');
          return {
            'reply': reply,
            'emotion': emotion,
            'action': _sanitizeAction(parsed['action'] as String?),
          };
        } catch (_) {}
      }
      // Fallback: raw text
      return {
        'reply': content,
        'emotion': _correctEmotion(content, 'neutral'),
        'action': 'talk'
      };
    }
  }

  /// 验证输入参数
  void _validateInput(Character character, String userMessage) {
    if (character.id.isEmpty) {
      throw ArgumentError('角色ID不能为空');
    }
    if (userMessage.trim().isEmpty) {
      throw ArgumentError('消息内容不能为空');
    }
    if (userMessage.length > AppConstants.maxMessageLength) {
      throw ArgumentError('消息长度超过限制(${AppConstants.maxMessageLength}字符)');
    }
  }

  /// 重置计数器（每小时重置）
  void _resetCounterIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastResetTime).inHours >= 1) {
      _requestCount = 0;
      _errorCount = 0;
      _lastResetTime = now;
    }
  }

  /// 获取API请求统计
  Map<String, int> getStats() {
    return {
      'totalRequests': _requestCount,
      'totalErrors': _errorCount,
      'errorRate': _requestCount > 0 ? (_errorCount * 100 ~/ _requestCount) : 0,
    };
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
