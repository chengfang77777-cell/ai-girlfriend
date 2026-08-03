import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/backgrounds.dart';
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
  bool _showApiKey = false;

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
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final storage = ref.read(storageServiceProvider);
    storage.setSetting(AppConstants.apiKeyKey, _apiKeyController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API Key 已保存'),
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
        storage.getSetting<String>('tts_voice') ??
            AppConstants.defaultVoice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Key Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'DeepSeek API Key',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: !_showApiKey,
                    decoration: InputDecoration(
                      hintText: '输入你的 API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _showApiKey
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _showApiKey = !_showApiKey;
                              });
                            },
                            tooltip: _showApiKey ? '隐藏' : '显示',
                          ),
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: _saveApiKey,
                            color: colorScheme.primary,
                            tooltip: '保存',
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _saveApiKey(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _apiKeyController.text.trim().isNotEmpty ? Colors.green : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _apiKeyController.text.trim().isNotEmpty ? 'API Key 已配置' : '尚未配置 API Key',
                        style: TextStyle(
                          fontSize: 12,
                          color: _apiKeyController.text.trim().isNotEmpty ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'API Key 将安全存储在本地',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
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
                            'tts_voice', value);
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
                      ref.read(backgroundIdProvider.notifier).state = null;
                      storage.setSetting('background_id', null);
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
                      'AI 模型', AppConstants.deepseekModel, colorScheme),
                  const Divider(),
                  _buildInfoRow(
                      'SDK', 'Flutter 3.2+', colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
