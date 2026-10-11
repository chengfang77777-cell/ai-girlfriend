import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// Chat input widget with rounded text field and send button.
///
/// Features a "说点什么吧..." hint, sage send button with
/// paper plane icon, loading spinner while sending.
/// Uses TextInputAction.send for keyboard submission.
class ChatInput extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController? controller;

  const ChatInput({
    super.key,
    this.onSend,
    this.isLoading = false,
    this.errorMessage,
    this.controller,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with WidgetsBindingObserver {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onTextChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    final previousValue = _controller.value;
    _controller.removeListener(_onTextChanged);
    if (oldWidget.controller == null) _controller.dispose();
    _controller =
        widget.controller ?? TextEditingController.fromValue(previousValue);
    _controller.addListener(_onTextChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Let the desktop FocusManager restore its suspended control first.
    Future.microtask(() {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      // Restore an idle chat, without taking focus from another control.
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus == null || primaryFocus is FocusScopeNode) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty && !widget.isLoading;

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
        color: AppTheme.bgCardLight,
        border: const Border(top: BorderSide(color: AppTheme.divider)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
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
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      hintText: '说点什么吧...',
                      hintStyle: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 15,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    // The default send action unfocuses before onSubmitted,
                    // including when a blank/loading draft cannot be sent.
                    onEditingComplete: _controller.clearComposing,
                    onSubmitted: (_) => _sendMessage(),
                    // Blank desktop clicks should not end typing. Other
                    // fields and routes still request their own focus normally.
                    onTapOutside: (_) {},
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
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
                  color: _canSend ? AppTheme.primaryColor : AppTheme.border,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Tooltip(
                  message: '发送消息',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
