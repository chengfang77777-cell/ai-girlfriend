import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Message type enum for chat bubble styling
enum MessageType {
  user,
  ai,
}

/// Chat bubble widget for displaying chat messages.
///
/// User messages: right-aligned, pink (#FF69B4) background, white text.
/// AI messages: left-aligned, light grey (#F5F5F5) background, dark text,
/// small avatar icon. Shows HH:mm timestamp. Max width 75% of screen.
/// Long press for copy/delete menu.
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
  bool _deleted = false;

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
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
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

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    final isUser = widget.type == MessageType.user;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        isUser ? MediaQuery.of(context).size.width * 0.7 : 50,
        100,
        isUser ? MediaQuery.of(context).size.width : 200,
        150,
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
        setState(() => _deleted = true);
        widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) {
      return const SizedBox.shrink();
    }

    final isUser = widget.type == MessageType.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.75;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: EdgeInsets.only(
            left: isUser ? screenWidth * 0.25 : 0,
            right: isUser ? 0 : screenWidth * 0.25,
            bottom: 4,
          ),
          child: GestureDetector(
            onLongPress: _handleLongPress,
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  margin: EdgeInsets.only(
                    top: 4,
                    bottom: 2,
                    left: isUser ? 0 : 8,
                    right: isUser ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [const Color(0xFFFF69B4).withOpacity(0.65), const Color(0xFFFF85A1).withOpacity(0.65)],
                          )
                        : null,
                    color: isUser ? null : const Color(0xFFF5F5F5).withOpacity(0.5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(6),
                      bottomRight: isUser ? const Radius.circular(6) : const Radius.circular(20),
                    ),
                    border: isUser
                        ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
                        : (widget.isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : null),
                    boxShadow: [
                      BoxShadow(
                        color: isUser ? const Color(0xFFFF69B4).withOpacity(0.12) : Colors.black.withOpacity(0.02),
                        blurRadius: isUser ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF69B4).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 16,
                            color: Color(0xFFFF69B4),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 15,
                                color: isUser ? Colors.white : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(widget.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isUser
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
