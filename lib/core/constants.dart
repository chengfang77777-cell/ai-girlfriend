class AppConstants {
  // App info
  static const String appName = 'AI 女友';
  static const String appVersion = '1.0.0';

  // DeepSeek API configuration
  static const String deepseekBaseUrl = 'https://api.deepseek.com';
  static const String deepseekModel = 'deepseek-chat';
  static const int apiTimeout = 30;

  // MiMo Chat(文本) API configuration
  // 官方文档：https://mimo.mi.com/docs/zh-CN/quick-start/summary/model（2026-07-15 更新）
  // V2 系列（mimo-v2-pro / flash）已于 2026-06-30 下线，当前文本模型为 v2.5 系列
  static const String mimoBaseUrl = 'https://api.xiaomimimo.com';
  static const String mimoChatModel = 'mimo-v2.5';

  // 对话模型供应商选择（值为 LlmProvider.deepseek / LlmProvider.mimo 的 id）
  static const String llmProviderKey = 'llm_provider';

  // Message limits
  static const int maxMessagesPerCharacter = 5000;
  static const int contextWindowSize = 30;
  static const int maxMessageLength = 2000;

  // Generation parameters
  static const int maxTokens = 2048;
  static const double temperature = 0.8;

  // Voice configuration - MiMo TTS
  static const String defaultVoice = '冰糖';
  static const String ttsVoiceKey = 'tts_voice';

  // Hive box names
  static const String messagesBox = 'messages';
  static const String charactersBox = 'characters';
  static const String settingsBox = 'settings';

  // SharedPreferences / Hive keys
  static const String currentCharKey = 'current_character_id';
  static const String apiKeyKey = 'deepseek_api_key';
  static const String mimoApiKeyKey = 'mimo_api_key';
  static const String autoPlayKey = 'auto_play_voice';
  static const String backgroundKey = 'background_id';

  // Default values
  static const String defaultGreeting = '你终于来啦～等你好久了呢！今天想聊什么呢？';
}
