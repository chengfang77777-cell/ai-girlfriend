import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/character_provider.dart';
import '../../models/character.dart';

class CharacterCreatePage extends ConsumerStatefulWidget {
  final Character? editingCharacter;

  const CharacterCreatePage({super.key, this.editingCharacter});

  @override
  ConsumerState<CharacterCreatePage> createState() =>
      _CharacterCreatePageState();
}

class _CharacterCreatePageState
    extends ConsumerState<CharacterCreatePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _styleController;
  late TextEditingController _voiceDescController;
  final Set<String> _selectedTraits = {};

  bool get _isEditing => widget.editingCharacter != null;

  static const List<String> _availableTraits = [
    '温柔', '活泼', '知性', '傲娇', '治愈',
    '体贴', '可爱', '成熟', '开朗', '包容',
    '幽默', '冷静', '热情', '神秘', '优雅',
    '元气', '软萌', '粘人', '腹黑', '天真',
  ];

  // 可选的 VRM 建模
  static const List<Map<String, String>> _availableModels = [
    {'name': '温柔学姐', 'file': 'senpai.vrm', 'desc': '温柔知性'},
    {'name': '活泼青梅', 'file': 'genki.vrm', 'desc': '元气活力'},
    {'name': '傲娇同桌', 'file': 'tsundere.vrm', 'desc': '倔强可爱'},
    {'name': '知性御姐', 'file': 'oneesan.vrm', 'desc': '优雅成熟'},
    {'name': '治愈邻家', 'file': 'iyashi.vrm', 'desc': '温暖治愈'},
    {'name': '拉姆', 'file': 'ram.vrm', 'desc': '毒舌傲娇'},
    {'name': '蕾姆', 'file': 'rem.vrm', 'desc': '温柔坚定'},
  ];

  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    final char = widget.editingCharacter;
    _nameController = TextEditingController(text: char?.name ?? '');
    _ageController =
        TextEditingController(text: char != null ? '${char.age}' : '');
    _styleController =
        TextEditingController(text: char?.speakingStyle ?? '');
    _voiceDescController =
        TextEditingController(text: char?.voiceDescription ?? '');
    if (char != null) {
      _selectedTraits.addAll(char.personalityTags);
      // 从已有角色的 modelPath 提取文件名
      final modelFile = char.avatarModelPath.split('/').last;
      _selectedModel = _availableModels.any((m) => m['file'] == modelFile)
          ? modelFile
          : _availableModels.first['file']!;
    } else {
      _selectedModel = _availableModels.first['file']!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _styleController.dispose();
    _voiceDescController.dispose();
    super.dispose();
  }

  void _toggleTrait(String trait) {
    setState(() {
      if (_selectedTraits.contains(trait)) {
        _selectedTraits.remove(trait);
      } else {
        _selectedTraits.add(trait);
      }
    });
  }

  String _generateId() {
    return 'custom_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _saveCharacter() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTraits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个性格标签')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 18;
    final style = _styleController.text.trim();
    final voiceDesc = _voiceDescController.text.trim();

    final character = Character(
      id: widget.editingCharacter?.id ?? _generateId(),
      name: name,
      age: age,
      personalityTags: _selectedTraits.toList(),
      speakingStyle: style,
      avatarModelPath: 'assets/models/$_selectedModel',
      isPreset: false,
      voiceDescription: voiceDesc.isNotEmpty ? voiceDesc : null,
    );

    if (_isEditing) {
      await ref.read(characterNotifierProvider.notifier).updateCharacter(character);
    } else {
      await ref.read(characterNotifierProvider.notifier).addCharacter(character);
      // Set the newly created character as current
      ref.read(currentCharacterIdProvider.notifier).state = character.id;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? '角色已更新' : '角色创建成功'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑角色' : '创建新角色'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar preview
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text.substring(0, 1)
                      : '?',
                  style: TextStyle(
                    fontSize: 36,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Model selector
            Text(
              '选择建模',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableModels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final model = _availableModels[index];
                  final isSelected = _selectedModel == model['file'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedModel = model['file']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.view_in_ar,
                            size: 32,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            model['name']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            model['desc']!,
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '角色名字',
                hintText: '输入角色的名字',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入角色名字';
                }
                if (value.trim().length > 20) {
                  return '名字不能超过20个字符';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Age field
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: '年龄',
                hintText: '输入角色年龄',
                prefixIcon: Icon(Icons.cake),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 999) {
                    return '请输入有效的年龄（1-999）';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Personality traits
            Text(
              '性格标签',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '选择角色的性格特点（至少选择一个）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _availableTraits.map((trait) {
                final isSelected = _selectedTraits.contains(trait);
                return FilterChip(
                  label: Text(trait),
                  selected: isSelected,
                  onSelected: (_) => _toggleTrait(trait),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
            if (_selectedTraits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '已选择: ${_selectedTraits.join('、')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
              ),
            const SizedBox(height: 24),

            // Speaking style
            TextFormField(
              controller: _styleController,
              decoration: const InputDecoration(
                labelText: '说话风格',
                hintText: '描述角色说话的方式和语气...',
                prefixIcon: Icon(Icons.record_voice_over),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请描述角色的说话风格';
                }
                if (value.trim().length > 500) {
                  return '描述不能超过500个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Voice description
            TextFormField(
              controller: _voiceDescController,
              decoration: const InputDecoration(
                labelText: '音色描述（可选）',
                hintText: '例如：温柔甜美的年轻女声，语速稍慢，带有撒娇感...',
                prefixIcon: Icon(Icons.mic),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              minLines: 2,
              validator: (value) {
                if (value != null && value.trim().length > 300) {
                  return '描述不能超过300个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '使用文本描述来设计专属音色，留空则使用默认音色',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: () => _saveCharacter(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isEditing ? '保存修改' : '创建角色',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
