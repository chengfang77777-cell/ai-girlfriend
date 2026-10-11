import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/character.dart';
import '../../domain/character_provider.dart';
import '../../domain/chat_provider.dart';
import '../widgets/character_card.dart';
import 'character_create_page.dart';

class CharacterListPage extends ConsumerWidget {
  const CharacterListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCharacters = ref.watch(allCharactersProvider);
    final currentId = ref.watch(currentCharacterIdProvider);
    final presets = allCharacters.where((c) => c.isPreset).toList();
    final custom = allCharacters.where((c) => !c.isPreset).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('角色管理')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              Text('找到合拍的陪伴',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('选择熟悉的她，或为一段新的对话创造专属角色。',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 28),
              _sectionTitle(context, '预设角色', presets.length),
              const SizedBox(height: 16),
              _characterGrid(context, ref, presets, currentId),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 12,
                children: [
                  _sectionTitle(context, '自定义角色', custom.length),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CharacterCreatePage(),
                    )),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('创建新角色'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (custom.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 36),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add_alt_1_outlined, size: 32),
                        const SizedBox(height: 16),
                        Text('还没有自定义角色',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text('从名字、性格和声音开始，创造你期待的陪伴。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              else
                _characterGrid(context, ref, custom, currentId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, int count) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(width: 10),
      Text('$count',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    ]);
  }

  Widget _characterGrid(BuildContext context, WidgetRef ref,
      List<Character> characters, String? currentId) {
    if (characters.isEmpty) return const Text('暂无预设角色');
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 250).floor().clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: characters
            .map((character) => SizedBox(
                  width: width,
                  child: CharacterCard(
                    name: character.name,
                    age: character.age,
                    personalityTags: character.personalityTags
                        .map((tag) => PersonalityTag(label: tag))
                        .toList(),
                    isSelected: character.id == currentId,
                    onTap: () {
                      ref.read(currentCharacterIdProvider.notifier).state =
                          character.id;
                      ref.read(messageRefreshProvider.notifier).state++;
                      Navigator.of(context).pop();
                    },
                    onEdit: character.isPreset
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => CharacterCreatePage(
                                      editingCharacter: character)),
                            ),
                    onDelete: character.isPreset
                        ? null
                        : () => _showDeleteConfirmation(
                              context,
                              ref,
                              character.id,
                              character.name,
                            ),
                    onClearChat: () async {
                      await ref
                          .read(chatNotifierProvider.notifier)
                          .clearChat(character.id);
                      ref.read(messageRefreshProvider.notifier).state++;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('已清除与「${character.name}」的聊天记录')),
                        );
                      }
                    },
                  ),
                ))
            .toList(),
      );
    });
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String characterId,
    String characterName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定要删除角色"$characterName"吗？\n该角色的所有聊天记录也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(characterNotifierProvider.notifier)
                  .deleteCharacter(characterId);
              // If deleted character was current, clear selection
              if (ref.read(currentCharacterIdProvider) == characterId) {
                ref.read(currentCharacterIdProvider.notifier).state = null;
              }
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
