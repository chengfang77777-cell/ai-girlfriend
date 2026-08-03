import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/character.dart';
import '../core/constants.dart';
import 'preset_characters.dart';
import '../core/secrets.dart';

/// 本地存储服务 - 负责Hive数据库的管理和操作
///
/// 架构设计要点：
/// 1. 单例模式确保全局唯一存储实例
/// 2. 分层缓存策略：内存缓存+磁盘持久化
/// 3. 事务性消息管理：批量操作原子性
/// 4. 容量管理：自动清理旧消息防止存储膨胀
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // 内存缓存提升读取性能
  final Map<String, List<Message>> _messageCache = {};
  final Set<String> _dirtyCharacters = {};

  late Box<Character> _charactersBox;
  late Box<Message> _messagesBox;
  late Box _settingsBox;

  // 公开访问器
  Box<Character> get charactersBox => _charactersBox;
  Box<Message> get messagesBox => _messagesBox;
  Box get settingsBox => _settingsBox;

  /// 初始化存储服务 - 必须在使用前调用
  Future<void> init() async {
    // Hive.initFlutter() 已在 main.dart 中调用，此处不再重复

    // 注册适配器需包裹在try-catch中防止重复注册
    try {
      Hive.registerAdapter(CharacterAdapter());
      Hive.registerAdapter(MessageAdapter());
    } catch (e) {
      debugPrint('Adapter already registered: $e');
    }

    // 打开Box，使用压缩策略
    _charactersBox = await Hive.openBox<Character>(
      AppConstants.charactersBox,
    );
    _messagesBox = await Hive.openBox<Message>(
      AppConstants.messagesBox,
    );
    _settingsBox = await Hive.openBox(
      AppConstants.settingsBox,
    );

    // 首次运行初始化预设角色
    if (_charactersBox.isEmpty) {
      await _initPresetCharacters();
    } else {
      // 强制更新预设角色数据（确保模型路径等字段最新）
      await _updatePresetCharacters();
    }

    // 预配置 DeepSeek API Key
    // 若本地未配置，或仍是旧的无效默认 key，则写入当前内置 key
    const legacyDefaultApiKey = 'sk-d6b641052e6f4d2fb37e4dfdbd396854';
    final storedApiKey = getSetting<String?>(AppConstants.apiKeyKey);
    if (storedApiKey == null || storedApiKey == legacyDefaultApiKey) {
      await setSetting(AppConstants.apiKeyKey, Secrets.deepseekApiKey);
    }

    debugPrint('StorageService initialized successfully');
  }

  // ========== 消息操作 ==========

  /// 添加消息 - 带容量自动清理
  Future<void> addMessage(Message message) async {
    // 先写入磁盘保证持久化
    await _messagesBox.put(message.id, message);

    // 更新内存缓存
    _messageCache.putIfAbsent(message.characterId, () => []);
    _messageCache[message.characterId]!.add(message);
    _messageCache[message.characterId]!
        .sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 标记角色为脏
    _dirtyCharacters.add(message.characterId);

    // 容量检查 - 延迟清理
    if (_messageCache[message.characterId]!.length >
        AppConstants.maxMessagesPerCharacter * 1.2) {
      await _trimMessageHistory(message.characterId);
    }
  }

  /// 批量添加消息（事务性）
  Future<void> addMessages(List<Message> messages) async {
    for (final message in messages) {
      await _messagesBox.put(message.id, message);
      _messageCache.putIfAbsent(message.characterId, () => []).add(message);
      _dirtyCharacters.add(message.characterId);
    }
  }

  /// 获取指定角色的消息列表
  List<Message> getMessages(String characterId) {
    // 优先从缓存读取
    if (_messageCache.containsKey(characterId)) {
      return List.unmodifiable(_messageCache[characterId]!);
    }

    // 缓存未命中，从数据库加载
    final messages = _messagesBox.values
        .where((m) => m.characterId == characterId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _messageCache[characterId] = messages;
    return List.unmodifiable(messages);
  }

  /// 删除单条消息
  Future<void> deleteMessage(String id) async {
    final msg = _messagesBox.get(id);
    if (msg != null) {
      await _messagesBox.delete(id);
      // 更新缓存
      if (_messageCache.containsKey(msg.characterId)) {
        _messageCache[msg.characterId]!.removeWhere((m) => m.id == id);
        _dirtyCharacters.add(msg.characterId);
      }
    }
  }

  /// 清空指定角色的所有消息
  Future<void> clearMessages(String characterId) async {
    // 使用事务批量删除
    final keys = _messagesBox.keys.where((k) {
      final msg = _messagesBox.get(k);
      return msg?.characterId == characterId;
    }).toList();

    if (keys.isNotEmpty) {
      for (final key in keys) {
        await _messagesBox.delete(key);
      }
    }

    // 清除缓存
    _messageCache.remove(characterId);
  }

  /// 清理超过容量上限的旧消息
  Future<void> _trimMessageHistory(String characterId) async {
    final messages = getMessages(characterId);
    if (messages.length <= AppConstants.maxMessagesPerCharacter) return;

    final toDelete = messages.sublist(
        0, messages.length - AppConstants.maxMessagesPerCharacter);

    for (final msg in toDelete) {
      await _messagesBox.delete(msg.id);
    }

    // 更新缓存
    _messageCache[characterId] =
        messages.sublist(messages.length - AppConstants.maxMessagesPerCharacter);
  }

  // ========== 角色操作 ==========

  /// 添加新角色
  Future<void> addCharacter(Character character) async {
    await _charactersBox.put(character.id, character);
  }

  /// 更新角色信息
  Future<void> updateCharacter(Character character) async {
    await _charactersBox.put(character.id, character);
  }

  /// 删除角色及关联消息
  Future<void> deleteCharacter(String id) async {
    // 先删除关联消息
    await clearMessages(id);
    // 再删除角色
    await _charactersBox.delete(id);
  }

  /// 获取单个角色
  Character? getCharacter(String id) {
    return _charactersBox.get(id);
  }

  /// 获取所有角色
  List<Character> getAllCharacters() {
    return _charactersBox.values.toList();
  }

  /// 获取自定义角色（非预设）
  List<Character> getCustomCharacters() {
    return _charactersBox.values.where((c) => !c.isPreset).toList();
  }

  // ========== 设置操作 ==========

  /// 获取设置值
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  /// 更新设置值
  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  // 便捷访问器
  String? get apiKey => getSetting<String?>(AppConstants.apiKeyKey);
  bool get autoPlayVoice =>
      getSetting<bool>(AppConstants.autoPlayKey, defaultValue: true) ?? true;
  String? get currentCharacterId =>
      getSetting<String?>(AppConstants.currentCharKey);

  // ========== 预设角色初始化 ==========

  /// 初始化预设角色
  Future<void> _initPresetCharacters() async {
    final presets = PresetCharacters.getPresets();
    for (final char in presets) {
      await _charactersBox.put(char.id, char);
    }

    // 默认选择第一个角色
    if (presets.isNotEmpty) {
      await _settingsBox.put(AppConstants.currentCharKey, presets.first.id);
    }
  }

  /// 更新预设角色数据（保留用户聊天记录，只更新角色属性）
  /// 新增的预设角色也会被添加
  Future<void> _updatePresetCharacters() async {
    final presets = PresetCharacters.getPresets();
    for (final char in presets) {
      final existing = _charactersBox.get(char.id);
      if (existing != null) {
        // 保留旧角色的消息，但更新角色属性
        await _charactersBox.put(char.id, char);
      } else {
        // 新增的预设角色
        await _charactersBox.put(char.id, char);
        debugPrint('New preset character added: ${char.name}');
      }
    }
    debugPrint('Preset characters updated');
  }

  /// 关闭存储服务
  Future<void> dispose() async {
    await _charactersBox.close();
    await _messagesBox.close();
    await _settingsBox.close();
    _messageCache.clear();
    _dirtyCharacters.clear();
  }
}
