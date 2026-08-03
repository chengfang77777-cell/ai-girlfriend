import 'dart:io' show File, Platform;
import 'package:path_provider/path_provider.dart';
import 'dart:math' show sin;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/character_provider.dart';
import '../../domain/chat_provider.dart';
import '../../domain/voice_provider.dart';
import '../../domain/background_provider.dart';
import '../widgets/avatar_display.dart' if (dart.library.html) '../widgets/avatar_display_web.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import 'character_list_page.dart';
import 'settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  /// 首次加载消息后自动跳到底部
  bool _didInitialScroll = false;
  String? _lastCharacterId;
  int _scrollRetries = 0;

  /// WAV bytes → write to vrm dir → set window._pendingAudioUrl
  /// The viewer polls _pendingAudioUrl in its animate() loop and plays + analyzes.
  /// Works on both Windows (webview_windows) and mobile (webview_flutter).
  void _sendAudioToLipSync(Uint8List wavBytes) {
    try {
      final dynamic state = _avatarKey.currentState;
      if (Platform.isWindows) {
        final dynamic ctrl = state?.windowsController;
        if (ctrl == null) return;
        _writeAudioAndPlay(ctrl, wavBytes, isWindows: true);
      } else {
        final dynamic ctrl = state?.mobileController;
        if (ctrl == null) return;
        _writeAudioAndPlay(ctrl, wavBytes, isWindows: false);
      }
    } catch (e) {
      debugPrint('[HomePage] lipSync send failed: $e');
    }
  }

  Future<void> _writeAudioAndPlay(dynamic ctrl, Uint8List wavBytes, {required bool isWindows}) async {
    try {
      // 先停止之前的音频播放
      if (isWindows) {
        ctrl.executeScript('stopCurrentAudio()');
      } else {
        await ctrl.runJavaScript('stopCurrentAudio()');
      }

      // 写入本地服务器目录（由 shelf 服务，与 vrm_viewer.html 同源）。
      // 浏览器端会基于 window._vrmBaseUrl 拼接出
      // http://127.0.0.1:<port>/audio.wav 进行播放。
      final appDocDir = await getApplicationDocumentsDirectory();
      final vrmDir = '${appDocDir.path}/vrm';
      final audioFile = File('$vrmDir/audio.wav');
      await audioFile.writeAsBytes(wavBytes, flush: true);
      debugPrint('[HomePage] wrote ${wavBytes.length} bytes to $vrmDir/audio.wav');
      if (isWindows) {
        ctrl.executeScript('window.__pendingAudioUrl = "audio.wav";');
      } else {
        await ctrl.runJavaScript('window.__pendingAudioUrl = "audio.wav";');
      }
      debugPrint('[HomePage] triggered lip-sync playback');
    } catch (e) {
      debugPrint('[HomePage] _writeAudioAndPlay error: $e');
    }
  }

  /// GlobalKey to look up the AvatarDisplay's state (Windows only).
  /// The concrete type differs per-platform (web uses iframe, no controller),
  /// so we keep this dynamic and only deref on Windows.
  final GlobalKey _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceNotifier = ref.read(voiceNotifierProvider.notifier);
      voiceNotifier.lipSyncSender = _sendAudioToLipSync;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    ref.read(voiceNotifierProvider.notifier).lipSyncSender = null;
    super.dispose();
  }

  /// 首次进入/切换角色后跳到最底部对话。
  /// ListView.builder 首帧 maxScrollExtent 可能不准（懒加载 item），需反复跳
  /// 直到 maxScrollExtent 连续两帧不变为止。
  double? _lastJumpExtent;
  void _jumpToBottomIfNeeded() {
    if (_didInitialScroll || _scrollRetries > 60) return;
    _scrollRetries++;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottomIfNeeded());
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(max);
    if (max == _lastJumpExtent || _scrollRetries > 20) {
      // extent 已稳定（或重试够多），完成初始滚动
      _didInitialScroll = true;
    } else {
      _lastJumpExtent = max;
      // 下一帧再跳一次，catch 懒加载导致 extent 增长的情况
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottomIfNeeded());
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      final isNearBottom = position.maxScrollExtent - position.pixels < 200;

      if (force || isNearBottom || position.pixels == 0) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleCtrlScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    final ctrlHeld = HardwareKeyboard.instance.isControlPressed;

    // Ctrl+scroll → zoom handled by webview directly (see vrm_viewer.html wheel listener)
    if (ctrlHeld) return;

    // Normal scroll → scroll chat list
    if (_scrollController.hasClients) {
      final newPos = (_scrollController.offset + delta).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(newPos);
    }
  }

  Future<void> _sendMessage(String text) async {
    final character = ref.read(currentCharacterProvider);
    if (character == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个角色')),
      );
      return;
    }

    ref.read(isSendingProvider.notifier).state = true;
    _scrollToBottom(force: true);

    // 通知WebView用户发送消息，停止待机动作
    _notifyUserSendMessage();

    try {
      final aiMessage = await ref.read(chatNotifierProvider.notifier).sendMessage(
            character.id,
            text,
          );
      // 触发消息刷新
      ref.read(messageRefreshProvider.notifier).state++;

      // TTS + 情绪/动作触发动画
      if (aiMessage != null) {
        // 由DeepSeek的 action 字段驱动身体动作（emotion 驱动面部表情）
        _triggerAction(aiMessage.action, aiMessage.emotion);

        final autoPlay = ref.read(autoPlayVoiceProvider);
        if (autoPlay) {
          final voice = character.voiceName.isNotEmpty
              ? character.voiceName
              : ref.read(storageServiceProvider)
                  .getSetting<String>('tts_voice') ?? '冰糖';
          final voiceDescription = character.voiceDescription;
          // 过滤掉括号内容后再TTS
          final filteredContent = _filterBrackets(aiMessage.content);
          ref.read(voiceNotifierProvider.notifier).speak(
            filteredContent,
            voice: voice,
            voiceDescription: voiceDescription,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        ref.read(isSendingProvider.notifier).state = false;
      }
    }

    _scrollToBottom(force: true);
  }

  void _notifyUserSendMessage() {
    final dynamic state = _avatarKey.currentState;
    final dynamic ctrl = Platform.isWindows
        ? state?.windowsController
        : state?.mobileController;
    if (ctrl == null) return;
    if (Platform.isWindows) {
      ctrl.executeScript("onUserSendMessage()");
    } else {
      ctrl.runJavaScript("onUserSendMessage()");
    }
  }

  // 过滤掉括号内容，用于TTS
  String _filterBrackets(String text) {
    return text.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();
  }

  void _triggerAction(String? action, String? emotion) {
    final dynamic state = _avatarKey.currentState;
    final dynamic ctrl = Platform.isWindows
        ? state?.windowsController
        : state?.mobileController;
    if (ctrl == null) return;

    final a = (action ?? 'talk').trim().toLowerCase();
    final e = (emotion ?? 'neutral').trim().toLowerCase();
    // 修正常见拼写错误
    final normalizedA = (a == 'netural' || a == 'natrual') ? 'talk' : a;
    final normalizedE = (e == 'netural' || e == 'natrual') ? 'neutral' : e;

    // 按动作名触发身体动画；未命中（talk/未知）时 webview 内部保持待机+口型
    final js = "triggerAction('$normalizedA','$normalizedE')";
    if (Platform.isWindows) {
      ctrl.executeScript(js);
    } else {
      ctrl.runJavaScript(js);
    }
  }

  Emotion _parseEmotion(String? emotionStr) {
    switch (emotionStr) {
      case 'shy':
        return Emotion.shy;
      case 'angry':
        return Emotion.angry;
      case 'sad':
        return Emotion.sad;
      case 'surprised':
        return Emotion.surprised;
      case 'neutral':
        return Emotion.neutral;
      default:
        return Emotion.happy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = ref.watch(currentCharacterProvider);
    final messages = ref.watch(currentMessagesProvider);
    final isSending = ref.watch(isSendingProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final background = ref.watch(currentBackgroundProvider);

    // 进入应用/切换角色后，首帧直接跳到对话最底部
    if (character?.id != _lastCharacterId) {
      _lastCharacterId = character?.id;
      _didInitialScroll = false;
      _scrollRetries = 0;
      _lastJumpExtent = null;
    }
    if (!_didInitialScroll && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottomIfNeeded());
    }

    // Get current emotion from last AI message
    final lastAiMsg = messages.where((m) => m.role == 'assistant').toList();
    final currentEmotion = lastAiMsg.isNotEmpty
        ? _parseEmotion(lastAiMsg.last.emotion)
        : Emotion.happy;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            character?.name ?? 'AI 女友',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CharacterListPage()),
                );
              },
              tooltip: '切换角色',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              tooltip: '设置',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Layer 1: Full-screen 3D model background
          // 注意：WebView 是原生 PlatformView，本身由系统独立合成层承载。
          // 给它套 RepaintBoundary 反而会让 Flutter 每帧多建一个离屏合成层、
          // 加重 GPU 合成负担（表现为模型+背景卡顿）。因此这里故意不包 RepaintBoundary，
          // 聊天列表层与滚动条层同理也不包（滚动条用 CustomPaint 的 repaint 隔离重绘）。
          Positioned.fill(
            child: AvatarDisplay(
              key: _avatarKey,
              characterName: character?.name ?? '选择角色',
              modelPath: character?.avatarModelPath,
              currentEmotion: currentEmotion,
              backgroundId: background.id,
            ),
          ),

          // Layer 2: Chat messages
          // Listener intercepts scroll: normal → chat, Ctrl → model zoom.
          // IgnorePointer lets drag pass through to webview for rotation.
          // 注意：不包 RepaintBoundary。聊天列表是纯 Flutter 控件，包 RepaintBoundary
          // 反而多建一个离屏合成层，与底层 WebView 原生层争抢 GPU，导致模型/背景卡顿。
          // 聊天滚动流畅度已由 CustomPaint 滚动条（repaint: controller）保证。
          Positioned(
            left: 0, right: 0, top: MediaQuery.of(context).padding.top + 56,
            bottom: 70,
            child: Listener(
                onPointerSignal: _handleCtrlScroll,
                behavior: HitTestBehavior.translucent,
                child: IgnorePointer(
                  child: messages.isEmpty && !isSending
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [colorScheme.primary.withOpacity(0.15), colorScheme.primary.withOpacity(0.05)],
                              ),
                            ),
                            child: Icon(Icons.chat_bubble_outline_rounded, size: 30, color: colorScheme.primary.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            character != null ? '💕 开始和${character.name}聊天吧' : '选择一个角色开始聊天',
                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text('发送第一条消息，开启你们的对话', style: TextStyle(color: colorScheme.outline.withOpacity(0.5), fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: messages.length + (isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isSending && index == messages.length) {
                          return const _TypingIndicator();
                        }

                        final message = messages[index];
                        final isUser = message.role == 'user';
                        return ChatBubble(
                          message: message.content,
                          type: isUser ? MessageType.user : MessageType.ai,
                          timestamp: message.timestamp,
                            onCopy: () {},
                            onDelete: () async {
                              final id = character?.id;
                              if (id == null) return;
                              await ref
                                  .read(chatNotifierProvider.notifier)
                                  .deleteMessage(id, message.id!);
                              ref.read(messageRefreshProvider.notifier).state++;
                            },
                        );
                      },
                    ),
                ),
              ),
          ),

          // Layer 3: 可交互的聊天滚动条（覆盖在 IgnorePointer 之上，可拖动）
          // 注：刻意不包 RepaintBoundary——聊天列表滚动重绘已由 _ThumbPainter
          // 的 repaint: controller 隔离，额外包层反而加重 GPU 合成负担导致卡顿。
          Positioned(
            right: 0,
            top: MediaQuery.of(context).padding.top + 56,
            bottom: 70,
            width: 16,
            child: _ChatScrollbar(controller: _scrollController),
          ),

          // Layer 4: Input area at bottom (interactive, stays on top)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ChatInput(
              onSend: _sendMessage,
              isLoading: isSending,
            ),
          ),
        ],
      ),
    );
  }
}

/// 自定义可拖动滚动条：绑定聊天列表的 ScrollController。
/// 因消息列表被 IgnorePointer 包裹（保证拖拽能穿透到 3D 模型），
/// 系统 Scrollbar 无法交互，故在其上层单独绘制一个可拖动的滚动条。
class _ChatScrollbar extends StatefulWidget {
  const _ChatScrollbar({required this.controller});

  final ScrollController controller;

  @override
  State<_ChatScrollbar> createState() => _ChatScrollbarState();
}

class _ChatScrollbarState extends State<_ChatScrollbar> {
  bool _dragging = false;
  bool _hovering = false;

  void _jumpToDy(double dy, double trackHeight) {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0 || !position.hasViewportDimension) return;
    final viewport = position.viewportDimension;
    final contentHeight = viewport + maxScroll;
    final thumbHeight =
        (viewport / contentHeight * trackHeight).clamp(36.0, trackHeight);
    final range = trackHeight - thumbHeight;
    if (range <= 0) return;
    final f = ((dy - thumbHeight / 2) / range).clamp(0.0, 1.0);
    widget.controller.jumpTo(f * maxScroll);
  }

  @override
  Widget build(BuildContext context) {
    // MouseRegion/GestureDetector 只在 hover/drag 状态变化时重建；
    // 滚动位置变化由 _ThumbPainter 通过 repaint: controller 监听，只触发 paint，不重建 widget
    final visible = _dragging || _hovering;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _jumpToDy(d.localPosition.dy, trackHeight),
            onVerticalDragStart: (d) {
              setState(() => _dragging = true);
              _jumpToDy(d.localPosition.dy, trackHeight);
            },
            onVerticalDragUpdate: (d) => _jumpToDy(d.localPosition.dy, trackHeight),
            onVerticalDragEnd: (_) => setState(() => _dragging = false),
            onVerticalDragCancel: () => setState(() => _dragging = false),
            child: CustomPaint(
              painter: _ThumbPainter(
                controller: widget.controller,
                visible: visible,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// 滚动条滑块绘制器：以 ScrollController 为 repaint 监听，
/// 滚动时只触发 paint（不触发 widget 重建），开销极低。
class _ThumbPainter extends CustomPainter {
  _ThumbPainter({required this.controller, required this.visible})
      : super(repaint: controller);

  final ScrollController controller;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0 || !position.hasViewportDimension) return;

    final trackHeight = size.height;
    final viewport = position.viewportDimension;
    final contentHeight = viewport + maxScroll;
    final thumbHeight =
        (viewport / contentHeight * trackHeight).clamp(36.0, trackHeight);
    final scrollFraction =
        maxScroll == 0 ? 0.0 : (position.pixels / maxScroll).clamp(0.0, 1.0);
    final thumbTop = scrollFraction * (trackHeight - thumbHeight);
    final thumbWidth = visible ? 8.0 : 6.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          size.width - thumbWidth - 3, thumbTop, thumbWidth, thumbHeight),
      const Radius.circular(4),
    );
    final paint = Paint()
      ..color = Colors.white.withOpacity(visible ? 0.85 : 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.visible != visible;
}

/// Typing indicator shown while waiting for AI response
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFF69B4), Color(0xFFFFB6C1)]),
            ),
            child: const Icon(Icons.favorite, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final t = (_animController.value - delay).clamp(0.0, 1.0);
                    final bounce = sin(t * 2 * 3.14159).abs();
                    final opacity = 0.3 + 0.7 * bounce;
                    final offsetY = -6.0 * bounce;
                    return Transform.translate(
                      offset: Offset(0, offsetY),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(opacity),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
