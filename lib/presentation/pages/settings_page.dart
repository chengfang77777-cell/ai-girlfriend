import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
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
    final currentVoice = storage.getSetting<String>(AppConstants.ttsVoiceKey) ??
        AppConstants.defaultVoice;
    final currentProvider = ref.watch(llmProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: false,
      ),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('让陪伴更合心意',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('调整对话、声音和空间，保留你喜欢的相处方式。',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 28),
                  _sectionHeading('对话与连接', '管理模型和服务密钥'),
                  // 对话模型供应商选择
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Row(
                            children: [
                              Icon(Icons.smart_toy),
                              SizedBox(width: 8),
                              Text(
                                '对话模型',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '选择用于日常聊天的模型，角色的性格与互动方式保持一致',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
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
                              ref.read(llmProviderProvider.notifier).state =
                                  next;
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
                    note: '用于 AI 对话，密钥仅存储在本地',
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

                  _sectionHeading('声音', '选择她的声音与朗读方式'),
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
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                          child: Row(
                            children: [
                              Icon(Icons.record_voice_over),
                              SizedBox(width: 8),
                              Text(
                                '默认音色',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '预设角色有专属音色，此设置仅对未配置音色的自定义角色生效',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
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

                  _sectionHeading('陪伴空间', '选择与你此刻心情相配的背景'),
                  _buildBackgroundCard(),
                  const SizedBox(height: 28),
                  _sectionHeading('应用与数据', '应用信息与聊天记录'),
                  // About section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '关于',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('应用名称', 'AI 女友', colorScheme),
                          const Divider(),
                          _buildInfoRow('版本', '1.0.0', colorScheme),
                          const Divider(),
                          _buildInfoRow(
                              'AI 模型',
                              '${currentProvider.name} ${currentProvider.model}',
                              colorScheme),
                          const Divider(),
                          _buildInfoRow('SDK', 'Flutter 3.2+', colorScheme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 危险操作：清除所有聊天记录
                  Card(
                    child: ListTile(
                      leading:
                          Icon(Icons.delete_sweep, color: colorScheme.error),
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
              ))),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _buildBackgroundCard() {
    final current = ref.watch(currentBackgroundProvider);
    final motion = ref.watch(backgroundMotionProvider);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('聊天背景',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 16),
        DropdownButtonFormField<BackgroundMotion>(
          key: const Key('background-motion'),
          value: motion,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '背景动效'),
          items: const [
            DropdownMenuItem(
                value: BackgroundMotion.gentle, child: Text('舒缓动态')),
            DropdownMenuItem(
                value: BackgroundMotion.still, child: Text('静态背景')),
            DropdownMenuItem(
                value: BackgroundMotion.system, child: Text('跟随系统')),
          ],
          onChanged: (mode) {
            if (mode != null) saveBackgroundMotion(ref, mode);
          },
        ),
        const SizedBox(height: 8),
        Text(
            switch (motion) {
              BackgroundMotion.gentle => '移动鼠标感受柔光，轻点泛起微光。陪学专注时会放缓动态。',
              BackgroundMotion.still => '保留背景层次，让画面安静下来。',
              BackgroundMotion.system => '使用系统的减少动画偏好。',
            },
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final count = (constraints.maxWidth / 150).floor().clamp(1, 6);
          final width = (constraints.maxWidth - (count - 1) * 12) / count;
          return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: PresetBackgrounds.all.map((bg) {
                final selected = current.id == bg.id;
                return SizedBox(
                    width: width,
                    child: Semantics(
                      selected: selected,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => saveBackgroundChoice(ref, bg.id),
                          child: Ink(
                            height: 106,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : AppTheme.border,
                                  width: selected ? 2 : 1),
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: bg.gradientColors),
                            ),
                            child: Column(children: [
                              Expanded(
                                  child: Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: selected
                                            ? const CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                                child: Icon(Icons.check,
                                                    color: Colors.white,
                                                    size: 14))
                                            : const SizedBox.shrink(),
                                      ))),
                              Container(
                                  width: double.infinity,
                                  color: Colors.white.withOpacity(0.92),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 9),
                                  child: Text(bg.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textPrimary))),
                            ]),
                          ),
                        ),
                      ),
                    ));
              }).toList());
        }),
        const SizedBox(height: 12),
        TextButton.icon(
            onPressed: () => resetBackgroundChoice(ref),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('恢复角色默认背景')),
      ]),
    ));
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                )),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: obscure,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: hint,
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
                    color:
                        configured ? AppTheme.primaryColor : AppTheme.textHint,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  configured ? '已填写 · 点击保存生效' : '尚未填写 API Key',
                  style: TextStyle(
                    fontSize: 12,
                    color: configured
                        ? AppTheme.primaryColor
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colorScheme) {
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
          const SizedBox(width: 20),
          Flexible(
              child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500),
          )),
        ],
      ),
    );
  }
}
