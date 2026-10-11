import 'package:flutter/material.dart';

/// Local avatar interaction, independent of chat and speech requests.
class HighFiveControl extends StatefulWidget {
  const HighFiveControl({
    super.key,
    required this.state,
    required this.enabled,
    required this.onStart,
    required this.onCancel,
  });

  final String state;
  final bool enabled;
  final Future<bool> Function() onStart;
  final Future<void> Function() onCancel;

  @override
  State<HighFiveControl> createState() => _HighFiveControlState();
}

class _HighFiveControlState extends State<HighFiveControl> {
  bool _starting = false;
  bool _cancelling = false;

  Future<void> _start() async {
    if (_starting || !widget.enabled || widget.state != 'idle') return;
    setState(() => _starting = true);
    var accepted = false;
    try {
      accepted = await widget.onStart();
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        if (!accepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请等角色准备好再试')),
          );
        }
      }
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await widget.onCancel();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        _starting && widget.state == 'idle' ? 'raising' : widget.state;
    final canStart = state == 'idle' && widget.enabled && !_starting;
    final canCancel = state == 'raising' || state == 'waiting';
    final label = switch (state) {
      'raising' => '抬手中…',
      'waiting' => '点击人物掌心',
      'hit' => '击掌成功！',
      'returning' => '收手中…',
      _ => '击个掌',
    };

    // Keep clicks in the same tap region as the chat field, including on desktop.
    return TextFieldTapRegion(
      child: Material(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: canStart ? _start : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor:
                    state == 'idle' ? Colors.white38 : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.back_hand_outlined, size: 18),
              label: Text(label),
            ),
            if (canCancel)
              TextButton(
                onPressed: _starting || _cancelling ? null : _cancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  disabledForegroundColor: Colors.white38,
                ),
                child: const Text('取消'),
              ),
          ],
        ),
      ),
    );
  }
}
