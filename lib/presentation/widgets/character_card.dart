import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class PersonalityTag {
  final String label;
  final Color color;

  const PersonalityTag(
      {required this.label, this.color = AppTheme.primaryColor});
}

/// A responsive character tile. Its parent owns its width and selection.
class CharacterCard extends StatelessWidget {
  final String name;
  final int age;
  final List<PersonalityTag> personalityTags;
  final String? avatarUrl;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClearChat;

  const CharacterCard({
    super.key,
    required this.name,
    required this.age,
    required this.personalityTags,
    this.avatarUrl,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onClearChat,
  });

  bool get isPreset => onEdit == null && onDelete == null;
  bool get _hasMenu =>
      onEdit != null || onDelete != null || onClearChat != null;

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除聊天记录'),
        content: Text('确定要清除与「$name」的全部聊天记录吗？\n此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.angry),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) onClearChat?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      child: Material(
        color: isSelected ? AppTheme.primarySoft : AppTheme.bgCardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        name.isNotEmpty ? name.characters.first : '?',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryDark),
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Tooltip(
                          message: '当前陪伴角色',
                          child: Icon(Icons.check_circle, size: 22)),
                    if (_hasMenu) _buildActionMenu(context),
                  ],
                ),
                const SizedBox(height: 20),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$age 岁 · ${isPreset ? '预设角色' : '自定义角色'}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: personalityTags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: tag.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(tag.label,
                                style:
                                    TextStyle(fontSize: 12, color: tag.color)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(isSelected ? '正在陪伴你' : '选择她，开始聊天',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.primaryColor)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '角色选项',
      icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'clear') _confirmClear(context);
        // The character list owns deletion and its confirmation dialog.
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('编辑角色')),
        if (onClearChat != null)
          const PopupMenuItem(value: 'clear', child: Text('清除聊天记录')),
        if (onDelete != null)
          const PopupMenuItem(
              value: 'delete',
              child: Text('删除角色', style: TextStyle(color: AppTheme.angry))),
      ],
    );
  }
}
