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
    this.nativeScrolling = false,
  });

  final ScrollController controller;
  final ValueChanged<double> onModelZoom;
  final Widget child;
  final bool nativeScrolling;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    final delta = event.scrollDelta.dy;
    if (HardwareKeyboard.instance.isControlPressed) {
      onModelZoom(delta);
      return;
    }
    if (nativeScrolling) return;
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
        child: nativeScrolling
            ? ScrollConfiguration(
                behavior: const _CompanionScrollBehavior(), child: child)
            : child,
      );
}

class _CompanionScrollBehavior extends MaterialScrollBehavior {
  const _CompanionScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _ControlScrollPhysics();
}

class _ControlScrollPhysics extends ClampingScrollPhysics {
  const _ControlScrollPhysics({super.parent});
  @override
  _ControlScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ControlScrollPhysics(parent: buildParent(ancestor));
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      !HardwareKeyboard.instance.isControlPressed &&
      super.shouldAcceptUserOffset(position);
}
