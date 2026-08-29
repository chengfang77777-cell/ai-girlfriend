import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Personality tag model for character cards
class PersonalityTag {
  final String label;
  final Color color;

  const PersonalityTag({
    required this.label,
    this.color = const Color(0xFFFF69B4),
  });
}

/// Character card widget displaying character info.
///
/// Rounded Card with avatar area, name, age, and personality tag chips.
/// Pink border when selected. onTap and onEdit/onDelete callbacks.
/// PopupMenuButton for edit/delete actions (hidden for preset characters
/// by omitting the callbacks).
class CharacterCard extends StatefulWidget {
  final String name;
  final int age;
  final List<PersonalityTag> personalityTags;
  final String? avatarUrl;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 清除该角色聊天记录（预设角色与自定义角色都可提供）
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

  /// Whether this card is for a preset character (no edit/delete)
  bool get isPreset => onEdit == null && onDelete == null;

  /// Whether the card should show an action menu (edit / clear chat / delete)
  bool get _hasMenu => onEdit != null || onDelete != null || onClearChat != null;

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('清除聊天记录'),
        content: Text(
            '确定要清除与"${widget.name}"的全部聊天记录吗？\n此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onClearChat?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('确认删除'),
        content: Text('确定要删除角色"${widget.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.96 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          width: 170,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFFF69B4)
                  : Colors.grey[200]!,
              width: widget.isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFFFF69B4).withOpacity(0.2)
                    : Colors.black.withOpacity(0.06),
                blurRadius: widget.isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action menu (shown when the card provides any action)
              if (widget._hasMenu)
                _buildActionMenu()
              else
                const SizedBox(height: 4),

              // Avatar area
              _buildAvatarSection(),

              // Info section
              _buildInfoSection(),

              // Personality tags
              _buildPersonalityTags(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu() {
    return Align(
      alignment: Alignment.topRight,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (value) {
          if (value == 'edit') {
            widget.onEdit?.call();
          } else if (value == 'clear') {
            _showClearChatConfirmation();
          } else if (value == 'delete') {
            _showDeleteConfirmation();
          }
        },
        itemBuilder: (context) => [
          if (widget.onEdit != null)
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text('编辑'),
                ],
              ),
            ),
          if (widget.onClearChat != null)
            PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 18, color: Colors.orange[400]),
                  const SizedBox(width: 8),
                  const Text('清除聊天记录'),
                ],
              ),
            ),
          if (widget.onDelete != null)
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: Colors.red[400]),
                  const SizedBox(width: 8),
                  const Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF69B4),
                Color(0xFFFF1493),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF69B4).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.name.isNotEmpty ? widget.name.substring(0, 1) : '?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.age}岁',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityTags() {
    if (widget.personalityTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: widget.personalityTags.map((tag) {
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tag.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tag.color.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              tag.label,
              style: TextStyle(
                fontSize: 11,
                color: tag.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
