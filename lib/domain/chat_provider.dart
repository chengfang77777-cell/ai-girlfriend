import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/message.dart';
import '../data/storage_service.dart';
import '../data/deepseek_api.dart';
import '../data/llm_provider.dart';
import 'character_provider.dart';

/// 当前选择的对话模型供应商（DeepSeek / 小米 MiMo）
///
/// 使用 StateProvider 而非 Provider：Provider 的结果会被永久缓存，
/// 切换供应商后 UI 与实际调用的客户端都拿不到新值。
/// 初始值从本地存储读取，切换时由调用方同时写存储并更新 state，
/// 以便 [llmApiProvider] 等依赖者自动重建。
final llmProviderProvider = StateProvider<LlmProvider>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LlmProvider.fromId(
      storage.getSetting<String>(AppConstants.llmProviderKey));
});

// 对话模型客户端 provider
// 按当前供应商取对应的 Key：MiMo 用 MiMo Key（与 TTS 同一个），其余用 DeepSeek Key
final llmApiProvider = Provider<DeepSeekApi?>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final provider = ref.watch(llmProviderProvider);
  final apiKey = provider.id == LlmProvider.mimo.id
      ? storage.mimoApiKey
      : storage.apiKey;
  if (apiKey == null || apiKey.isEmpty) return null;
  return DeepSeekApi(apiKey: apiKey, provider: provider);
});

// 消息刷新计数器——每次发消息+1，触发UI重建
final messageRefreshProvider = StateProvider<int>((ref) => 0);

// 当前角色的消息列表（监听刷新计数器）
final currentMessagesProvider = Provider<List<Message>>((ref) {
  ref.watch(messageRefreshProvider); // 监听刷新信号
  final storage = ref.watch(storageServiceProvider);
  final currentId = ref.watch(currentCharacterIdProvider);
  if (currentId == null) return [];
  return storage.getMessages(currentId);
});

// 消息发送状态
final isSendingProvider = StateProvider<bool>((ref) => false);

// 聊天操作Notifier
class ChatNotifier extends StateNotifier<Map<String, List<Message>>> {
  final StorageService _storage;
  final DeepSeekApi? _api;

  ChatNotifier(this._storage, this._api) : super({});

  /// 发送消息并获取AI回复
  /// 返回AI生成的Message对象，如果发送失败则返回null
  Future<Message?> sendMessage(String characterId, String content) async {
    if (_api == null) return null;

    final character = _storage.getCharacter(characterId);
    if (character == null) return null;

    // 创建用户消息并保存
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      characterId: characterId,
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    await _storage.addMessage(userMessage);

    try {
      // 获取历史消息（不包括刚添加的用户消息）
      final history = _storage
          .getMessages(characterId)
          .where((m) => m.id != userMessage.id)
          .toList();

      // 调用DeepSeek API
      final response = await _api.sendMessage(
        character: character,
        history: history,
        userMessage: content,
      );

      // 创建AI回复消息并保存
      final aiMessage = Message(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        characterId: characterId,
        role: 'assistant',
        content: response['reply'] ?? '',
        timestamp: DateTime.now(),
        emotion: response['emotion'] ?? 'neutral',
        action: response['action'],
      );
      await _storage.addMessage(aiMessage);

      // 更新状态
      state = {...state, characterId: _storage.getMessages(characterId)};
      return aiMessage;
    } catch (e) {
      // 发生错误时重新抛出，由调用方处理
      rethrow;
    }
  }

  /// 删除指定消息
  Future<void> deleteMessage(String characterId, String messageId) async {
    await _storage.deleteMessage(messageId);
    state = {...state, characterId: _storage.getMessages(characterId)};
  }

  /// 清除指定角色的全部聊天记录
  Future<void> clearChat(String characterId) async {
    await _storage.clearMessages(characterId);
    state = {...state, characterId: <Message>[]};
  }

  /// 清除所有角色的聊天记录
  Future<void> clearAllChats() async {
    await _storage.clearAllMessages();
    state = {};
  }
}

// 聊天Managed Provider
final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, Map<String, List<Message>>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final api = ref.watch(llmApiProvider);
  return ChatNotifier(storage, api);
});
