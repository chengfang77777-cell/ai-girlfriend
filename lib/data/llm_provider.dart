import '../core/constants.dart';

/// 对话模型（LLM）供应商配置。
///
/// 目前两家供应商都兼容 OpenAI Chat Completions 协议，差异仅在于：
/// 1. baseUrl
/// 2. 模型名
/// 3. 认证头（DeepSeek 用 `Authorization: Bearer`，MiMo 用 `api-key`）
/// 4. 生成长度参数名（DeepSeek 用 `max_tokens`，MiMo 用 `max_completion_tokens`）
///
/// 提示词构建与回复后处理逻辑由 [DeepSeekApi] 统一实现，
/// 切换供应商不会改变任何 prompt 内容，保证行为一致。
class LlmProvider {
  /// 存储/标识用的 id
  final String id;

  /// 设置页展示名
  final String name;

  /// 说明文案
  final String description;

  /// 接口根地址（已包含版本号，如 https://api.deepseek.com/v1）
  final String baseUrl;

  /// 模型名
  final String model;

  /// true → 使用 `api-key` 请求头；false → 使用 `Authorization: Bearer`
  final bool useApiKeyHeader;

  /// true → 使用 `max_completion_tokens`；false → 使用 `max_tokens`
  final bool useMaxCompletionTokens;

  const LlmProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.baseUrl,
    required this.model,
    required this.useApiKeyHeader,
    required this.useMaxCompletionTokens,
  });

  /// DeepSeek（默认供应商）
  static const deepseek = LlmProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    description: 'deepseek-chat，对话稳定、成本低',
    baseUrl: '${AppConstants.deepseekBaseUrl}/v1',
    model: AppConstants.deepseekModel,
    useApiKeyHeader: false,
    useMaxCompletionTokens: false,
  );

  /// 小米 MiMo
  /// 模型名依据官方文档（mimo.mi.com/docs/zh-CN/quick-start/summary/model，
  /// 2026-07-15 更新）：V2 系列已于 2026-06-30 下线，当前文本模型为 v2.5 系列。
  /// 默认使用 mimo-v2.5（性价比更高），需要更强推理时可改为 mimo-v2.5-pro。
  static const mimo = LlmProvider(
    id: 'mimo',
    name: '小米 MiMo',
    description: 'mimo-v2.5，与 TTS 共用同一个 API Key',
    baseUrl: '${AppConstants.mimoBaseUrl}/v1',
    model: AppConstants.mimoChatModel,
    useApiKeyHeader: true,
    useMaxCompletionTokens: true,
  );

  /// 可选供应商列表（设置页按此顺序展示）
  static const List<LlmProvider> all = [deepseek, mimo];

  /// 按 id 解析供应商，未知值回退到 DeepSeek
  static LlmProvider fromId(String? id) {
    for (final provider in all) {
      if (provider.id == id) return provider;
    }
    return deepseek;
  }
}
