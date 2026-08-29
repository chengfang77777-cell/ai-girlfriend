import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/backgrounds.dart';
import '../../data/llm_provider.dart';
import '../../domain/chat_provider.dart';
import '../../domain/character_provider.dart';
import '../../domain/voice_provider.dart';
import '../../domain/background_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _apiKeyController;
  late TextEditingController _mimoApiKeyController;
  bool _showApiKey = false;
  bool _showMimoApiKey = false;

  static const Map<String, String> _ttsVoices = {
    '冰糖': '冰糖 (温柔沉稳)',
    '茉莉': '茉莉 (甜美元气)',
  };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _apiKeyController = TextEditingController(
      text: storage.apiKey ?? '',
    );
    _mimoApiKeyController = TextEditingController(
      text: storage.mimoApiKey ?? '',
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _mimoApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey({
    required String storageKey,
    required String value,
    required String label,
  }) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setSetting(storageKey, value.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final autoPlayVoice = ref.watch(autoPlayVoiceProvider);
    final storage = ref.read(storageServiceProvider);
    final currentVoice =
        storage.getSetting<String>(AppConstants.ttsVoiceKey) ??
            AppConstants.defaultVoice;
    final currentProvider = ref.watch(llmProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 对话模型供应商选择
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.smart_toy),
                      SizedBox(width: 8),
                      Text(
                        '对话模型',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '切换供应商不会改变任何提示词，回复的情绪/动作判定逻辑完全一致',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                ...LlmProvider.all.map(
                  (provider) => RadioListTile<String>(
                    title: Text(provider.name),
                    subtitle: Text(provider.description),
                    value: provider.id,
                    groupValue: currentProvider.id,
                    onChanged: (value) async {
                      if (value == null) return;
                      final next = LlmProvider.fromId(value);
                      await storage.setSetting(
                          AppConstants.llmProviderKey, next.id);
                      // 同步更新 Riverpod 状态，避免 Provider 缓存导致切换无效
                      ref.read(llmProviderProvider.notifier).state = next;
                    },
                    activeColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // DeepSeek API Key Section
          _buildApiKeyCard(
            title: 'DeepSeek API Key',
            icon: Icons.key,
            controller: _apiKeyController,
            obscure: !_showApiKey,
            hint: '输入你的 DeepSeek API Key',
            note: '用于 AI 对话，密钥仅安全存储在本地',
            onToggleVisibility: () {
              setState(() {
                _showApiKey = !_showApiKey;
              });
            },
            onSave: () {
              _saveApiKey(
                storageKey: AppConstants.apiKeyKey,
                value: _apiKeyController.text,
                label: 'DeepSeek API Key',
              );
            },
          ),
          const SizedBox(height: 16),

          // MiMo TTS API Key Section
          _buildApiKeyCard(
            title: 'MiMo TTS API Key',
            icon: Icons.record_voice_over,
            controller: _mimoApiKeyController,
            obscure: !_showMimoApiKey,
            hint: '输入你的 MiMo TTS API Key',
            note: '用于语音合成与 MiMo 对话模型，留空则回退到内置 Key',
            onToggleVisibility: () {
              setState(() {
                _showMimoApiKey = !_showMimoApiKey;
              });
            },
            onSave: () {
              _saveApiKey(
                storageKey: AppConstants.mimoApiKeyKey,
                value: _mimoApiKeyController.text,
                label: 'MiMo TTS API Key',
              );
            },
          ),
          const SizedBox(height: 16),

          // Auto-play voice switch
          Card(
            child: SwitchListTile(
              title: const Text('自动朗读'),
              subtitle: const Text('AI 回复后自动朗读'),
              secondary: const Icon(Icons.volume_up),
              value: autoPlayVoice,
              onChanged: (value) {
                ref.read(autoPlayVoiceProvider.notifier).state = value;
                storage.setSetting(AppConstants.autoPlayKey, value);
              },
            ),
          ),
          const SizedBox(height: 8),

          // TTS Voice selection
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over),
                      SizedBox(width: 8),
                      Text(
                        '默认 TTS 音色',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '预设角色有专属音色，此设置仅对未配置音色的自定义角色生效',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._ttsVoices.entries.map(
                  (entry) => RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: currentVoice,
                    onChanged: (value) {
                      if (value != null) {
                        storage.setSetting(
                            AppConstants.ttsVoiceKey, value);
                        setState(() {});
                      }
                    },
                    activeColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Background selection
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.wallpaper, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '聊天背景',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '选择聊天界面的背景效果，每个预设角色有默认背景',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: PresetBackgrounds.all.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final bg = PresetBackgrounds.all[index];
                      final currentBg = ref.watch(currentBackgroundProvider);
                      final isSelected = bg.id == currentBg.id;

                      return GestureDetector(
                        onTap: () {
                          saveBackgroundChoice(ref, bg.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: bg.gradientColors,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(11),
                                    bottomRight: Radius.circular(11),
                                  ),
                                ),
                                child: Text(
                                  bg.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Reset to character default
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      resetBackgroundChoice(ref);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('恢复角色默认背景'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '关于',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                      '应用名称', 'AI 女友', colorScheme),
                  const Divider(),
                  _buildInfoRow(
                      '版本', '1.0.0', colorScheme),
                  const Divider(),
                  _buildInfoRow(
                      'AI 模型',
                      '${currentProvider.name} ${currentProvider.model}',
                      colorScheme),
                  const Divider(),
                  _buildInfoRow(
                      'SDK', 'Flutter 3.2+', colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 危险操作：清除所有聊天记录
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_sweep, color: colorScheme.error),
              title: Text(
                '清除所有聊天记录',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('删除全部角色的对话记录，此操作不可恢复'),
              onTap: () {
                _showClearAllConfirmation();
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 清除所有角色的聊天记录（带二次确认）
  Future<void> _showClearAllConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('清除所有聊天记录'),
        content: const Text(
          '将删除全部角色的对话记录，此操作不可恢复。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(chatNotifierProvider.notifier).clearAllChats();
    ref.read(messageRefreshProvider.notifier).state++;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除所有角色的聊天记录')),
    );
  }

  /// 通用 API Key 输入卡片（DeepSeek / MiMo TTS 共用）
  Widget _buildApiKeyCard({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required bool obscure,
    required String hint,
    required String note,
    required VoidCallback onToggleVisibility,
    required VoidCallback onSave,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final configured = controller.text.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: obscure,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: onToggleVisibility,
                      tooltip: obscure ? '显示' : '隐藏',
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: onSave,
                      color: colorScheme.primary,
                      tooltip: '保存',
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) {
                onSave();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: configured ? Colors.green : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  configured ? 'API Key 已配置' : '尚未配置 API Key',
                  style: TextStyle(
                    fontSize: 12,
                    color: configured
                        ? Colors.green.shade700
                        : colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
