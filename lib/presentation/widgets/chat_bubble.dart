import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// Message type enum for chat bubble styling
enum MessageType {
  user,
  ai,
}

/// Chat bubble widget for displaying chat messages.
///
/// Messages size themselves against their chat panel, with a timestamp and
/// a long-press / secondary-click menu for copy and delete.
class ChatBubble extends StatefulWidget {
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final bool isSelected;

  const ChatBubble({
    super.key,
    required this.message,
    required this.type,
    required this.timestamp,
    this.onCopy,
    this.onDelete,
    this.isSelected = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showActions(Offset globalPosition) {
    HapticFeedback.mediumImpact();
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              const Text('复制'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
              const SizedBox(width: 8),
              const Text('删除'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: widget.message));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已复制到剪贴板'),
            duration: Duration(seconds: 1),
          ),
        );
        widget.onCopy?.call();
      } else if (value == 'delete') {
        // 由上层数据源负责删除并刷新列表，避免本地状态与数据源不同步导致消息闪现
        widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.type == MessageType.user;
    return LayoutBuilder(builder: (context, constraints) {
      final panelWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      return FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPressStart: (details) =>
                    _showActions(details.globalPosition),
                onSecondaryTapDown: (details) =>
                    _showActions(details.globalPosition),
                child: Container(
                  constraints:
                      BoxConstraints(maxWidth: (panelWidth - 24) * 0.88),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.bubbleUser : AppTheme.bubbleAi,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 18),
                    ),
                    border: Border.all(
                      color: widget.isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.border,
                      width: widget.isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(widget.timestamp),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
