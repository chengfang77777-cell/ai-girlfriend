import 'package:flutter_test/flutter_test.dart';
import 'package:ai_girlfriend/data/llm_provider.dart';

void main() {
  test('deepseek 供应商配置正确', () {
    expect(LlmProvider.deepseek.baseUrl, 'https://api.deepseek.com/v1');
    expect(LlmProvider.deepseek.model, 'deepseek-chat');
    expect(LlmProvider.deepseek.useApiKeyHeader, false);
    expect(LlmProvider.deepseek.useMaxCompletionTokens, false);
  });

  test('mimo 供应商配置正确', () {
    expect(LlmProvider.mimo.baseUrl, 'https://api.xiaomimimo.com/v1');
    expect(LlmProvider.mimo.model, 'mimo-v2.5');
    expect(LlmProvider.mimo.useApiKeyHeader, true);
    expect(LlmProvider.mimo.useMaxCompletionTokens, true);
  });

  test('fromId 解析与回退', () {
    expect(LlmProvider.fromId('mimo').model, 'mimo-v2.5');
    expect(LlmProvider.fromId(null).id, 'deepseek');
    expect(LlmProvider.fromId('unknown').id, 'deepseek');
  });
}
