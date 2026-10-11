import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:math' show sin, min;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../domain/character_provider.dart';
import '../../domain/chat_provider.dart';
import '../../domain/voice_provider.dart';
import '../../domain/background_provider.dart';
import '../widgets/avatar_display.dart'
    if (dart.library.html) '../widgets/avatar_display_web.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_wheel_region.dart';
import '../widgets/high_five_control.dart';
import '../widgets/study_panel.dart';
import '../widgets/study_music_panel.dart';
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
  int _replyGeneration = 0;
  String? _reactionId;
  String _interactionState = 'idle';
  bool _studyMode = false;
  bool _studyQuiet = false;
  bool _musicOpen = false;
  bool _musicMinimized = false;
  final ScrollController _studyScrollController = ScrollController();

  void _stopStudyReply() {
    if (!mounted) return;
    ++_replyGeneration;
    _reactionId = null;
    ref.read(voiceNotifierProvider.notifier).stop();
    _stopAvatarAudio();
  }

  void _setStudyQuiet(bool quiet) {
    _stopStudyReply();
    setState(() => _studyQuiet = quiet);
  }

  void _toggleStudy() {
    ++_replyGeneration;
    _reactionId = null;
    ref.read(voiceNotifierProvider.notifier).stop();
    _stopAvatarAudio();
    _cancelHighFive();
    setState(() {
      _studyMode = !_studyMode;
      if (!_studyMode) _musicOpen = false;
      _studyQuiet = false;
      _interactionState = 'idle';
    });
  }

  Future<void> _studyReply(
      String text, String emotion, bool celebrate, String action) async {
    final character = ref.read(currentCharacterProvider);
    if (!_studyMode || character == null) return;
    final generation = ++_replyGeneration;
    _reactionId = 'study:${character.id}:$generation';
    ref.read(voiceNotifierProvider.notifier).stop();
    // Local sound and gesture start immediately; remote speech can follow later.
    final dynamic avatar = _avatarKey.currentState;
    if (celebrate && avatar != null) {
      try {
        await avatar.celebrateStudyCompletion(_reactionId);
      } catch (error) {
        debugPrint('[Study] Completion effect unavailable: $error');
      }
    } else {
      _triggerAction(action, emotion);
    }
    if (!mounted ||
        !_studyMode ||
        generation != _replyGeneration ||
        ref.read(currentCharacterIdProvider) != character.id) return;
    if (ref.read(autoPlayVoiceProvider)) {
      final settingVoice = ref
              .read(storageServiceProvider)
              .getSetting<String>(AppConstants.ttsVoiceKey) ??
          AppConstants.defaultVoice;
      final rawVoice =
          character.voiceName.isNotEmpty ? character.voiceName : settingVoice;
      final voice =
          const {'冰糖', '茉莉'}.contains(rawVoice) ? rawVoice : settingVoice;
      ref.read(voiceNotifierProvider.notifier).speak(
            _filterBrackets(text),
            characterId: character.id,
            voice: voice,
            voiceDescription: character.voiceDescription,
          );
    }
  }

  Future<void> _sendAudioToLipSync(Uint8List wavBytes) async {
    final dynamic state = _avatarKey.currentState;
    if (state == null) throw StateError('播放器尚未就绪，请重试');
    await state.playAudio(wavBytes, reactionId: _reactionId);
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
      voiceNotifier.stopPlayback = _stopAvatarAudio;
      voiceNotifier.onTtsError = (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                action: SnackBarAction(
                    label: '重试语音',
                    onPressed: () {
                      voiceNotifier.retry();
                    })),
          );
        }
      };
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _studyScrollController.dispose();
    _inputController.dispose();
    final voiceNotifier = ref.read(voiceNotifierProvider.notifier);
    voiceNotifier.stop();
    voiceNotifier.stopPlayback = null;
    voiceNotifier.lipSyncSender = null;
    voiceNotifier.onTtsError = null;
    super.dispose();
  }

  /// 首次进入/切换角色后跳到最底部对话。
  /// ListView.builder 首帧 maxScrollExtent 可能不准（懒加载 item），需反复跳
  /// 直到 maxScrollExtent 连续两帧不变为止。
  double? _lastJumpExtent;
  void _jumpToBottomIfNeeded() {
    if (!mounted || _studyMode || _didInitialScroll || _scrollRetries > 60) {
      return;
    }
    _scrollRetries++;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpToBottomIfNeeded());
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpToBottomIfNeeded());
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

  Future<void> _zoomModel(double delta) async {
    if (!delta.isFinite) return;
    final dynamic state = _avatarKey.currentState;
    if (state == null) return;
    try {
      final script = 'window.zoomModelByWheel?.($delta);';
      if (Platform.isWindows) {
        await state.windowsController?.executeScript(script);
      } else {
        await state.mobileController?.runJavaScript(script);
      }
    } catch (error) {
      debugPrint('[HomePage] Model zoom failed: $error');
    }
  }

  Future<void> _stopAvatarAudio() async {
    final dynamic state = _avatarKey.currentState;
    if (state == null) return;
    try {
      await state.stopAudio();
    } catch (error) {
      debugPrint('[HomePage] Stop audio failed: $error');
    }
  }

  Future<bool> _startHighFive() async {
    if (ref.read(isSendingProvider) ||
        ref.read(voiceStatusProvider) != null ||
        ref.read(currentCharacterProvider) == null) {
      return false;
    }
    final dynamic state = _avatarKey.currentState;
    if (state == null) return false;
    try {
      return await state.startHighFive() == true;
    } catch (error) {
      debugPrint('[HomePage] High five unavailable: $error');
      return false;
    }
  }

  Future<void> _cancelHighFive() async {
    final dynamic state = _avatarKey.currentState;
    if (state == null) return;
    try {
      await state.cancelHighFive();
    } catch (error) {
      debugPrint('[HomePage] Cancel high five failed: $error');
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

    // 未配置 API Key 时给出明确引导，而不是发消息后无响应
    final api = ref.read(llmApiProvider);
    if (api == null) {
      final providerName = ref.read(llmProviderProvider).name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先在「设置」中配置 $providerName API Key')),
      );
      return;
    }

    ref.read(isSendingProvider.notifier).state = true;
    _scrollToBottom(force: true);

    final generation = ++_replyGeneration;
    _reactionId = null;
    ref.read(voiceNotifierProvider.notifier).stop();
    await _stopAvatarAudio();
    if (!mounted) return;
    // 通知WebView用户发送消息，停止待机动作
    _notifyUserSendMessage();

    try {
      final aiMessage =
          await ref.read(chatNotifierProvider.notifier).sendMessage(
                character.id,
                text,
              );
      // 触发消息刷新
      if (!mounted) return;
      ref.read(messageRefreshProvider.notifier).state++;

      // TTS + 情绪/动作触发动画
      if (aiMessage != null &&
          generation == _replyGeneration &&
          ref.read(currentCharacterIdProvider) == character.id) {
        _reactionId = '${character.id}:$generation';
        // 由DeepSeek的 action 字段驱动身体动作（emotion 驱动面部表情）
        _triggerAction(aiMessage.action, aiMessage.emotion);

        final autoPlay = ref.read(autoPlayVoiceProvider);
        if (autoPlay) {
          // MiMo TTS 支持的有效语音名（与设置页一致）
          const supportedVoices = {'冰糖', '茉莉'};
          final settingVoice = ref
                  .read(storageServiceProvider)
                  .getSetting<String>(AppConstants.ttsVoiceKey) ??
              AppConstants.defaultVoice;
          final rawVoice = character.voiceName.isNotEmpty
              ? character.voiceName
              : settingVoice;
          // 兜底：历史数据可能存过无效语音名（如 zh-CN-XiaoxiaoNeural），
          // 或自定义角色未设置有效语音时，回退到设置里的语音
          final voice =
              supportedVoices.contains(rawVoice) ? rawVoice : settingVoice;
          final voiceDescription = character.voiceDescription;
          // 过滤掉括号内容后再TTS
          final filteredContent = _filterBrackets(aiMessage.content);
          ref.read(voiceNotifierProvider.notifier).speak(
                filteredContent,
                characterId: character.id,
                voice: voice,
                voiceDescription: voiceDescription,
              );
        }
      }
    } catch (e) {
      if (mounted) {
        // 将底层异常映射为友好提示，避免把原始堆栈/响应体直接展示给用户
        final err = e.toString();
        String tip;
        if (err.contains('认证') || err.contains('401')) {
          tip = 'API Key 无效或已过期，请在设置中检查';
        } else if (err.contains('超时') || err.contains('Timeout')) {
          tip = '请求超时，请检查网络后重试';
        } else if (err.contains('客户端') || err.contains('Client')) {
          tip = '网络连接异常，请检查网络后重试';
        } else {
          tip = '发送失败，请稍后重试';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tip)),
        );
      }
    } finally {
      if (mounted) {
        ref.read(isSendingProvider.notifier).state = false;
      }
    }

    _scrollToBottom(force: true);
  }

  /// 清除当前角色的聊天记录（带二次确认，仅影响该角色）
  Future<void> _showClearChatConfirmation() async {
    final character = ref.read(currentCharacterProvider);
    if (character == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('清除聊天记录'),
        content: Text(
          '确定要清除与"${character.name}"的全部聊天记录吗？\n'
          '仅清除该角色的对话，其他角色的记录不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(chatNotifierProvider.notifier).clearChat(character.id);
    ref.read(messageRefreshProvider.notifier).state++;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清除与"${character.name}"的聊天记录')),
    );
  }

  void _notifyUserSendMessage() {
    final dynamic state = _avatarKey.currentState;
    final dynamic ctrl =
        Platform.isWindows ? state?.windowsController : state?.mobileController;
    if (ctrl == null) return;
    if (Platform.isWindows) {
      ctrl.executeScript('onUserSendMessage()');
    } else {
      ctrl.runJavaScript('onUserSendMessage()');
    }
  }

  // 过滤掉括号内容，用于TTS
  String _filterBrackets(String text) {
    return text.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();
  }

  void _triggerAction(String? action, String? emotion) {
    final dynamic state = _avatarKey.currentState;
    final dynamic ctrl =
        Platform.isWindows ? state?.windowsController : state?.mobileController;
    if (ctrl == null) return;

    final a = (action ?? 'talk').trim().toLowerCase();
    final e = (emotion ?? 'neutral').trim().toLowerCase();
    // 修正常见拼写错误
    final normalizedA = (a == 'netural' || a == 'natrual') ? 'talk' : a;
    final normalizedE = (e == 'netural' || e == 'natrual') ? 'neutral' : e;

    // 按动作名触发身体动画；未命中（talk/未知）时 webview 内部保持待机+口型
    final js = 'triggerAction(${jsonEncode(normalizedA)},'
        '${jsonEncode(normalizedE)},${jsonEncode(_reactionId)})';
    if (Platform.isWindows) {
      ctrl.executeScript(js);
    } else {
      ctrl.runJavaScript(js);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentCharacterIdProvider, (previous, next) {
      if (previous == next) return;
      ++_replyGeneration;
      _reactionId = null;
      _studyMode = false;
      _musicOpen = false;
      _studyQuiet = false;
      _triggerAction('talk', 'neutral');
      ref.read(voiceNotifierProvider.notifier).stop();
      _stopAvatarAudio();
    });
    final character = ref.watch(currentCharacterProvider);
    final messages = ref.watch(currentMessagesProvider);
    final isSending = ref.watch(isSendingProvider);
    final voiceStatus = ref.watch(voiceStatusProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final background = ref.watch(currentBackgroundProvider);
    final backgroundMotion = ref.watch(backgroundMotionProvider);

    // 进入应用/切换角色后，首帧直接跳到对话最底部
    if (character?.id != _lastCharacterId) {
      _lastCharacterId = character?.id;
      _interactionState = 'idle';
      _didInitialScroll = false;
      _scrollRetries = 0;
      _lastJumpExtent = null;
    }
    if (!_studyMode && !_didInitialScroll && messages.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpToBottomIfNeeded());
    }

    final activeScroll =
        _studyMode ? _studyScrollController : _scrollController;
    final panel = _studyMode && character != null
        ? StudyPanel(
            key: ValueKey('study:${character.id}'),
            scrollController: _studyScrollController,
            onClose: _toggleStudy,
            onQuietChanged: _setStudyQuiet,
            onMessageStart: _stopStudyReply,
            onReply: _studyReply,
            onOpenMusic: () => setState(() {
              if (_musicOpen && _musicMinimized) {
                _musicMinimized = false;
              } else {
                _musicOpen = !_musicOpen;
                _musicMinimized = false;
              }
            }),
            musicOpen: _musicOpen,
          )
        : Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 12),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('慢慢说，我在听',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('和${character?.name ?? '她'}的日常',
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                  IconButton(
                      onPressed:
                          character == null ? null : _showClearChatConfirmation,
                      tooltip: '清除聊天记录',
                      icon: const Icon(Icons.delete_outline_rounded, size: 20)),
                ]),
              ),
              const Divider(),
              Expanded(
                  child: messages.isEmpty && !isSending
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Icon(Icons.forum_outlined,
                                    size: 38,
                                    color: colorScheme.primary.withOpacity(.5)),
                                const SizedBox(height: 18),
                                Text(character == null ? '选一个想见的人' : '今天过得怎么样？',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    character == null
                                        ? '从右上角进入角色列表。'
                                        : '开心的小事，或者说不出口的烦恼，\n都可以在这里聊一聊。',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(height: 1.8)),
                              ])))
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            key: PageStorageKey('chat:${character?.id}'),
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 18),
                            itemCount: messages.length + (isSending ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return const _TypingIndicator();
                              }
                              final message = messages[index];
                              return ChatBubble(
                                  key: ValueKey(message.id),
                                  message: message.content,
                                  type: message.role == 'user'
                                      ? MessageType.user
                                      : MessageType.ai,
                                  timestamp: message.timestamp,
                                  onCopy: () {},
                                  onDelete: () async {
                                    if (character == null) return;
                                    await ref
                                        .read(chatNotifierProvider.notifier)
                                        .deleteMessage(
                                            character.id, message.id);
                                    ref
                                        .read(messageRefreshProvider.notifier)
                                        .state++;
                                  });
                            },
                          ))),
              ChatInput(
                  controller: _inputController,
                  onSend: _sendMessage,
                  isLoading: isSending),
            ]),
          );

    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
          child: Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.favorite_outline_rounded,
                    size: 21, color: colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(character?.name ?? '遇见，让日常柔软一点',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(_studyMode ? '一起专注，也允许偶尔歇一歇' : '留一点时间，给彼此',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
            if (character != null)
              FilledButton.tonalIcon(
                onPressed: isSending ? null : _toggleStudy,
                icon: Icon(
                    _studyMode
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.menu_book_rounded,
                    size: 18),
                label: Text(_studyMode ? '回到聊天' : '陪我学习'),
              ),
            const SizedBox(width: 8),
            IconButton(
                tooltip: '切换角色',
                icon: const Icon(Icons.people_outline_rounded),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CharacterListPage()))),
            IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()))),
          ]),
        ),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final sidebarWidth =
              min(420.0, constraints.maxWidth * .35).clamp(360.0, 420.0);
          final panelHeight =
              wide ? constraints.maxHeight - 16 : constraints.maxHeight * .52;
          return Stack(children: [
            Positioned(
                left: 16,
                right: wide ? sidebarWidth + 32 : 16,
                top: 0,
                bottom: wide ? 16 : panelHeight + 28,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(children: [
                      Positioned.fill(
                          child: ChatWheelRegion(
                              controller: activeScroll,
                              onModelZoom: _zoomModel,
                              child: AvatarDisplay(
                                key: _avatarKey,
                                characterName: character?.name ?? '选择角色',
                                modelPath: character?.avatarModelPath,
                                currentEmotion: Emotion.neutral,
                                backgroundId: background.id,
                                backgroundMotion: backgroundMotion.name,
                                studyQuiet: _studyQuiet,
                                onAudioStarted: () => ref
                                    .read(voiceStatusProvider.notifier)
                                    .state = '正在说话…',
                                onInteractionState: (state) {
                                  if (mounted &&
                                      ref.read(currentCharacterIdProvider) ==
                                          character?.id &&
                                      state != _interactionState) {
                                    setState(() => _interactionState = state);
                                  }
                                },
                              ))),
                      Positioned(
                          top: 18,
                          left: 18,
                          child: _StageLabel(
                              icon: _studyMode
                                  ? Icons.spa_outlined
                                  : Icons.favorite_border,
                              text: _studyMode ? '你的陪学搭子' : '此刻，陪着你')),
                      Positioned(
                          left: 18,
                          bottom: 18,
                          right: 170,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: _StageLabel(
                                  icon: voiceStatus == null
                                      ? Icons.touch_app_outlined
                                      : Icons.graphic_eq_rounded,
                                  text: voiceStatus ??
                                      (Platform.isWindows
                                          ? '拖动转身 · Ctrl + 滚轮缩放'
                                          : '单指拖动转身 · 双指缩放')))),
                      if (!_studyMode && character != null)
                        Positioned(
                            right: 18,
                            bottom: 18,
                            child: HighFiveControl(
                                key: ValueKey(character.id),
                                state: _interactionState,
                                enabled: !isSending && voiceStatus == null,
                                onStart: _startHighFive,
                                onCancel: _cancelHighFive)),
                    ]))),
            Positioned(
                right: 16,
                left: wide ? null : 16,
                bottom: 16,
                top: wide ? 0 : null,
                width: wide ? sidebarWidth : null,
                height: wide ? null : panelHeight,
                child: ChatWheelRegion(
                    controller: activeScroll,
                    onModelZoom: _zoomModel,
                    nativeScrolling: true,
                    child: panel)),
            if (_studyMode && _musicOpen)
              Positioned(
                  left: 28,
                  top: _musicMinimized ? null : 12,
                  height: _musicMinimized ? 208 : null,
                  width: _musicMinimized
                      ? min(
                          360.0,
                          wide
                              ? constraints.maxWidth - sidebarWidth - 72
                              : constraints.maxWidth - 56)
                      : null,
                  right: _musicMinimized
                      ? null
                      : wide
                          ? sidebarWidth + 44
                          : 28,
                  bottom: wide ? 28 : panelHeight + 40,
                  child: StudyMusicPanel(
                      minimized: _musicMinimized,
                      onToggleMinimized: () =>
                          setState(() => _musicMinimized = !_musicMinimized),
                      onClose: () => setState(() => _musicOpen = false))),
          ]);
        })),
      ])),
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(.32),
            borderRadius: BorderRadius.circular(14)),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: Colors.white.withOpacity(.85)),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white, height: 1.4))),
            ])),
      );
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
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFF527564), Color(0xFF8DA88D)]),
            ),
            child: const Icon(Icons.favorite, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
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
                        width: 9,
                        height: 9,
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
