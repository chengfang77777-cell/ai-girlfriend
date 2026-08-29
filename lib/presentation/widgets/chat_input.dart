import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chat input widget with rounded text field and send button.
///
/// Features a "说点什么吧..." hint, pink circular send button with
/// paper plane icon, loading spinner while sending.
/// Uses TextInputAction.send for keyboard submission.
class ChatInput extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final bool isLoading;
  final String? errorMessage;

  const ChatInput({
    super.key,
    this.onSend,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // _controller.dispose() 会自行清理已注册的 listener，无需手动移除
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _controller.text.trim().isNotEmpty && !widget.isLoading;

  void _sendMessage() {
    final text = _controller.text.trim();
    if (!_canSend) return;

    HapticFeedback.lightImpact();
    widget.onSend?.call(text);
    _controller.clear();
    // 保持输入框焦点
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.errorMessage!,
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text input field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? const Color(0xFFFF69B4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      hintText: '说点什么吧...',
                      hintStyle: TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 15,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted:
                        widget.isLoading ? null : (_) => _sendMessage(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _canSend
                      ? const Color(0xFFFF69B4)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _canSend ? _sendMessage : null,
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
