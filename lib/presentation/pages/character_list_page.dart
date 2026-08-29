import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    final presetCharacters =
        allCharacters.where((c) => c.isPreset).toList();
    final customCharacters =
        allCharacters.where((c) => !c.isPreset).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色管理'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preset characters section
          Text(
            '预设角色',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (presetCharacters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '暂无预设角色',
                  style: TextStyle(color: colorScheme.outline),
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presetCharacters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final character = presetCharacters[index];
                  return CharacterCard(
                    name: character.name,
                    age: character.age,
                    personalityTags: character.personalityTags
                        .map((tag) => PersonalityTag(label: tag))
                        .toList(),
                    isSelected: character.id == currentId,
                    onTap: () {
                      ref
                          .read(currentCharacterIdProvider.notifier)
                          .state = character.id;
                      ref.read(messageRefreshProvider.notifier).state++;
                      Navigator.of(context).pop();
                    },
                    onClearChat: () async {
                      await ref
                          .read(chatNotifierProvider.notifier)
                          .clearChat(character.id);
                      ref.read(messageRefreshProvider.notifier).state++;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '已清除与"${character.name}"的聊天记录'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 32),

          // Custom characters section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '自定义角色',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (customCharacters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_alt_1,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '还没有自定义角色',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击下方按钮创建你的专属角色',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...customCharacters.map((character) {
              return CharacterCard(
                name: character.name,
                age: character.age,
                personalityTags: character.personalityTags
                    .map((tag) => PersonalityTag(label: tag))
                    .toList(),
                isSelected: character.id == currentId,
                onTap: () {
                  ref
                      .read(currentCharacterIdProvider.notifier)
                      .state = character.id;
                  ref.read(messageRefreshProvider.notifier).state++;
                  Navigator.of(context).pop();
                },
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CharacterCreatePage(editingCharacter: character),
                    ),
                  );
                },
                onDelete: () {
                  _showDeleteConfirmation(context, ref, character.id,
                      character.name);
                },
                onClearChat: () async {
                  await ref
                      .read(chatNotifierProvider.notifier)
                      .clearChat(character.id);
                  ref.read(messageRefreshProvider.notifier).state++;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('已清除与"${character.name}"的聊天记录'),
                      ),
                    );
                  }
                },
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const CharacterCreatePage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('创建新角色'),
      ),
    );
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
