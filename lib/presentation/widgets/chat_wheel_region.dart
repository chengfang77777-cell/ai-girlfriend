import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Routes desktop wheel input without taking over pointer drags from the model.
class ChatWheelRegion extends StatelessWidget {
  const ChatWheelRegion({
    super.key,
    required this.controller,
    required this.onModelZoom,
    required this.child,
  });

  final ScrollController controller;
  final ValueChanged<double> onModelZoom;
  final Widget child;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    final delta = event.scrollDelta.dy;
    if (HardwareKeyboard.instance.isControlPressed) {
      onModelZoom(delta);
      return;
    }
    if (!controller.hasClients) return;
    final position = controller.position;
    controller.jumpTo((position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble());
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: _onPointerSignal,
        child: child,
      );
}
