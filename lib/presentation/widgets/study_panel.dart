import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/storage_service.dart';
import '../../data/study_companion.dart';
import '../../domain/character_provider.dart';
import '../../domain/chat_provider.dart';
import '../../domain/study_session.dart';
import '../../models/character.dart';
import '../../models/message.dart';

/// A companion beside the existing avatar. Speech and avatar effects belong to
/// HomePage so a study session never creates a second viewer or voice player.
class StudyPanel extends ConsumerStatefulWidget {
  const StudyPanel({
    super.key,
    required this.onClose,
    required this.onQuietChanged,
    required this.onReply,
    this.onMessageStart,
    this.scrollController,
    this.onOpenMusic,
    this.musicOpen = false,
  });

  final VoidCallback onClose;
  final ValueChanged<bool> onQuietChanged;

  /// Interrupt prior speech without changing the countdown or quiet idle mode.
  final VoidCallback? onMessageStart;
  final ScrollController? scrollController;
  final VoidCallback? onOpenMusic;
  final bool musicOpen;
  final Future<void> Function(
      String text, String emotion, bool celebrate, String action) onReply;

  @override
  ConsumerState<StudyPanel> createState() => _StudyPanelState();
}

class _StudyPanelState extends ConsumerState<StudyPanel> {
  final _session = StudySessionController();
  final _minutes = TextEditingController(text: '25');
  final _goal = TextEditingController();
  final _draft = TextEditingController();
  final _nextStep = TextEditingController();
  final _draftFocus = FocusNode();
  late final ScrollController _scroll;
  final _history = <Message>[];
  late final StorageService _storage;
  late final Character? _character;
  late final String _storageKey;
  Timer? _ticker;
  Future<void> _writes = Future<void>.value();
  String? _error;
  String? _saveError;
  String? _validation;
  String? _failedText;
  List<Message>? _failedHistory;
  int _generation = 0;
  int _messageSequence = 0;
  int _ticksSinceSave = 0;
  bool _busy = false;
  bool _completionDelivered = false;
  bool _closing = false;
  bool _recordCleared = false;

  @override
  void initState() {
    super.initState();
    _scroll = widget.scrollController ?? ScrollController();
    _storage = ref.read(storageServiceProvider);
    _character = ref.read(currentCharacterProvider);
    _storageKey = 'study_session:${_character?.id ?? 'none'}';
    final saved = _storage.getSetting<dynamic>(_storageKey);
    if (saved is Map) {
      _session.restore(saved);
      _goal.text = _session.goal;
      _minutes.text =
          (_session.duration.inMinutes > 0 ? _session.duration.inMinutes : 25)
              .toString();
      _nextStep.text =
          saved['nextStep'] is String ? saved['nextStep'] as String : '';
    }
    _completionDelivered = _session.phase == StudyPhase.completed;
    _session.addListener(_onSessionChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session.phase == StudyPhase.focusing && ++_ticksSinceSave >= 30) {
        _ticksSinceSave = 0;
        _persist();
      }
    });
  }

  void _onSessionChanged() {
    if (!mounted || _closing) return;
    if (_session.phase == StudyPhase.completed && !_completionDelivered) {
      _completionDelivered = true;
      _cancelReply();
      widget.onQuietChanged(false);
      final praise = studyCompletionPraise(
        characterName: _character?.name ?? '我',
        goal: _session.goal,
        elapsedSeconds: _session.elapsed.inSeconds,
      );
      _history.add(_message('assistant', praise, emotion: 'happy'));
      _persist();
      // Text is available immediately; a speech failure never removes it.
      unawaited(_deliver(praise, 'happy', true, action: 'happy'));
      _scrollToLatest();
    }
    setState(() {});
  }

  Message _message(String role, String text,
          {String emotion = 'neutral', String action = 'talk'}) =>
      Message(
        id: 'study-${DateTime.now().microsecondsSinceEpoch}-${_messageSequence++}',
        characterId: _character?.id ?? '',
        role: role,
        content: text,
        timestamp: DateTime.now(),
        emotion: emotion,
        action: action,
      );

  Future<void> _deliver(String text, String emotion, bool celebrate,
      {String action = 'talk'}) async {
    final token = _generation;
    try {
      await widget.onReply(text, emotion, celebrate, action);
    } catch (_) {
      if (mounted && !_closing && token == _generation) {
        setState(() => _error = '声音暂时没能播放，文字会留在这里。');
      }
    }
  }

  Future<void> _persist({bool clear = false}) {
    if (_recordCleared && !clear) return _writes;
    final snapshot = clear
        ? null
        : <String, dynamic>{
            ..._session.toJson(),
            'goal': _goal.text.trim(),
            'nextStep': _nextStep.text.trim(),
          };
    // Capture both the value and storage now: disposed widgets never read ref.
    _writes = _writes
        .then((_) => _storage.setSetting(_storageKey, snapshot))
        .then<void>((_) {
      if (mounted && !_closing && _saveError != null) {
        setState(() => _saveError = null);
      }
    }).catchError((Object error) {
      if (mounted && !_closing) {
        setState(() => _saveError = '进度暂未保存，请重试。');
      }
    });
    return _writes;
  }

  void _cancelReply() {
    _generation++;
    _busy = false;
    _error = null;
    _failedText = null;
    _failedHistory = null;
  }

  bool get _fresh =>
      _session.phase == StudyPhase.ready ||
      _session.phase == StudyPhase.completed ||
      _session.phase == StudyPhase.ended;

  void _focus() {
    _cancelReply();
    if (_fresh) {
      final minutes = int.tryParse(_minutes.text);
      if (minutes == null || minutes < 1 || minutes > 240) {
        setState(() => _validation = '请输入 1–240 分钟。');
        return;
      }
      _validation = null;
      _completionDelivered = false;
      _recordCleared = false;
      _session.start(
          duration: Duration(minutes: minutes), goal: _goal.text.trim());
    } else {
      _session.resume();
    }
    widget.onQuietChanged(_session.phase == StudyPhase.focusing);
    _persist();
    setState(() {});
  }

  void _pause({StudyPhase phase = StudyPhase.paused}) {
    _cancelReply();
    widget.onQuietChanged(false);
    _session.pause(phase: phase);
    _persist();
    setState(() {});
  }

  void _rest() {
    _pause(phase: StudyPhase.resting);
    setState(() {
      _history.add(_message('assistant', '好，先歇一会儿。不用补回这段时间，想继续时我还在。'));
    });
    _scrollToLatest();
  }

  void _end() {
    _cancelReply();
    _session.finish();
    widget.onQuietChanged(false);
    setState(() {
      _history.add(_message('assistant', '那今天就到这里。愿意的话，留一句下次从哪里继续；现在可以安心休息。'));
    });
    _persist();
    _scrollToLatest();
  }

  Future<void> _send(String raw,
      {bool retry = false, bool fromDraft = false}) async {
    if (_busy || _closing) return;
    final text = raw.trim();
    if (text.isEmpty) {
      _draftFocus.requestFocus();
      return;
    }
    final previous = retry
        ? List<Message>.of(_failedHistory ?? [])
        : List<Message>.of(
            _history.skip(_history.length > 12 ? _history.length - 12 : 0));
    final token = ++_generation;
    widget.onMessageStart?.call();
    setState(() {
      _busy = true;
      _error = null;
      _failedText = text;
      _failedHistory = previous;
      if (!retry) _history.add(_message('user', text));
      if (fromDraft) _draft.clear();
    });
    if (fromDraft) _draftFocus.requestFocus();
    _persist();
    _scrollToLatest();
    try {
      final api = ref.read(llmApiProvider);
      if (api == null || _character == null) {
        throw StateError('missing configuration');
      }
      final response = await api.sendMessage(
        character: _character,
        history: previous,
        userMessage: text,
        additionalSystemPrompt: buildStudySystemPrompt(
              goal: _session.goal.isEmpty ? _goal.text.trim() : _session.goal,
              elapsedSeconds: _session.elapsed.inSeconds,
            ) +
            (_nextStep.text.trim().isEmpty
                ? ''
                : '\n用户主动留下的下次继续提示：${_nextStep.text.trim()}'),
      );
      if (!mounted || _closing || token != _generation) return;
      final reply = response['reply']?.trim() ?? '';
      if (reply.isEmpty) throw StateError('empty reply');
      final emotion = response['emotion'] ?? 'neutral';
      final action = response['action'] ?? 'talk';
      setState(() {
        _busy = false;
        _failedText = null;
        _failedHistory = null;
        _history.add(
            _message('assistant', reply, emotion: emotion, action: action));
      });
      _scrollToLatest();
      unawaited(_deliver(reply, emotion, false, action: action));
    } catch (_) {
      if (!mounted || _closing || token != _generation) return;
      setState(() {
        _busy = false;
        _error = '暂时没能收到回复。可以重试，也可以先安静待一会儿。';
      });
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  void _close() {
    _pause();
    _closing = true;
    widget.onClose();
  }

  Future<void> _clearRecord() async {
    final clear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('清除本次陪学记录？'),
              content: const Text('将清除本地目标、计时和续学提示。本次陪学对话也会清空。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('保留')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('清除')),
              ],
            ));
    if (clear != true || !mounted) return;
    _cancelReply();
    _completionDelivered = true;
    _session.restore(null);
    _recordCleared = true;
    _goal.clear();
    _nextStep.clear();
    _minutes.text = '25';
    _draft.clear();
    _history.clear();
    widget.onQuietChanged(false);
    await _persist(clear: true);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _closing = true;
    _generation++;
    _ticker?.cancel();
    _session.removeListener(_onSessionChanged);
    _session.pause();
    if (!_recordCleared) _persist();
    _session.dispose();
    _minutes.dispose();
    _goal.dispose();
    _draft.dispose();
    _nextStep.dispose();
    _draftFocus.dispose();
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  String get _phaseLabel => switch (_session.phase) {
        StudyPhase.ready => '按你的节奏来',
        StudyPhase.focusing => '安静陪着你',
        StudyPhase.paused => '已暂停，随时继续',
        StudyPhase.supporting => '我在，慢慢说',
        StudyPhase.resting => '休息也是照顾自己',
        StudyPhase.completed => '这一段，完成了',
        StudyPhase.ended => '今天辛苦了',
      };

  String _clock(Duration duration) {
    final seconds = ((duration.inMilliseconds + 999) ~/ 1000).clamp(0, 86400);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final focusing = _session.phase == StudyPhase.focusing;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 480;
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: Column(children: [
              Row(children: [
                Icon(Icons.spa_outlined, color: colors.primary, size: 22),
                const SizedBox(width: 9),
                Expanded(
                    child: Text('陪我学习',
                        style: Theme.of(context).textTheme.titleLarge)),
                if (widget.onOpenMusic != null)
                  IconButton(
                      tooltip: widget.musicOpen ? '收起网易云音乐' : '网易云音乐',
                      onPressed: widget.onOpenMusic,
                      icon: Icon(Icons.headphones_rounded,
                          color: widget.musicOpen
                              ? colors.primary
                              : colors.onSurfaceVariant)),
                IconButton(
                    tooltip: '清除陪学记录',
                    onPressed: _clearRecord,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20)),
                IconButton(
                    tooltip: '收起陪学',
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, size: 20)),
              ]),
              SizedBox(height: compact ? 4 : 12),
              Container(
                padding: EdgeInsets.all(compact ? 10 : 16),
                decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(.5),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_phaseLabel,
                              style: TextStyle(
                                  color: colors.primary, fontSize: 12)),
                          Text(
                              _session.phase == StudyPhase.ready
                                  ? '${_minutes.text.padLeft(2, '0')}:00'
                                  : _clock(_session.remaining),
                              style: TextStyle(
                                  fontSize: compact ? 30 : 42,
                                  fontWeight: FontWeight.w300,
                                  color: colors.onSurface,
                                  height: 1.25,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ])),
                    FilledButton.icon(
                        onPressed: focusing ? () => _pause() : _focus,
                        icon: Icon(
                            focusing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18),
                        label: Text(focusing
                            ? '暂停'
                            : _fresh
                                ? '开始陪学'
                                : '继续学习')),
                  ]),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            minHeight: 4,
                            value: _session.phase == StudyPhase.ready
                                ? 0
                                : (_session.elapsed.inMilliseconds /
                                        _session.duration.inMilliseconds)
                                    .clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withOpacity(.7))),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            focusing ? '聊几句也没关系，计时会继续。' : '按你的节奏来，休息也没关系。',
                            style: TextStyle(
                                fontSize: 11, color: colors.onSurfaceVariant))),
                  ],
                ]),
              ),
              SizedBox(height: compact ? 6 : 12),
              Expanded(
                  child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                          controller: _scroll,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_fresh) ...[
                                  TextField(
                                      key: const Key('study-goal'),
                                      controller: _goal,
                                      maxLength: 120,
                                      decoration: const InputDecoration(
                                          hintText: '今天想做什么？（可不填）',
                                          counterText: ''),
                                      onChanged: (_) => _recordCleared = false),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        child: TextField(
                                            key: const Key('study-minutes'),
                                            controller: _minutes,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  3)
                                            ],
                                            decoration: const InputDecoration(
                                                labelText: '陪学时长',
                                                suffixText: '分钟'),
                                            onChanged: (_) => setState(() {}))),
                                    const SizedBox(width: 8),
                                    for (final minutes in [5, 25, 45])
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4),
                                          child: ActionChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              label: Text('$minutes'),
                                              onPressed: () => setState(() =>
                                                  _minutes.text = '$minutes'))),
                                  ]),
                                  if (_validation != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(_validation!,
                                            style: TextStyle(
                                                color: colors.error,
                                                fontSize: 12))),
                                  const SizedBox(height: 12),
                                ] else if (_session.goal.isNotEmpty) ...[
                                  Text('这一段 · ${_session.goal}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 10),
                                ],
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  OutlinedButton(
                                      onPressed:
                                          _busy ? null : () => _send('我学不下去了'),
                                      child: const Text('我学不下去了')),
                                  TextButton(
                                      onPressed: _rest,
                                      child: const Text('想休息一下')),
                                  TextButton(
                                      onPressed: _end,
                                      child: const Text('今天先到这里')),
                                ]),
                                if (_session.phase == StudyPhase.ended ||
                                    _nextStep.text.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _nextStep,
                                      maxLength: 200,
                                      decoration: const InputDecoration(
                                          hintText: '下次从这里继续…（会用于陪伴回复）',
                                          counterText: ''),
                                      onChanged: (_) {
                                        _recordCleared = false;
                                        _persist();
                                      }),
                                ],
                                if (_saveError != null)
                                  Row(children: [
                                    Expanded(
                                        child: Text(_saveError!,
                                            style: TextStyle(
                                                color: colors.error,
                                                fontSize: 12))),
                                    TextButton(
                                        onPressed: () =>
                                            _persist(clear: _recordCleared),
                                        child: const Text('重试保存')),
                                  ]),
                                const SizedBox(height: 14),
                                if (_history.isEmpty)
                                  Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: Text(
                                          '我就在这里陪着你。\n想说话时随时叫我，不用先把事情做完。',
                                          style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              height: 1.8,
                                              fontSize: 13))),
                                for (final message in _history)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Align(
                                          alignment: message.isUser
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                              constraints: BoxConstraints(
                                                  maxWidth: constraints.maxWidth -
                                                      68),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 11),
                                              decoration: BoxDecoration(
                                                  color: message.isUser
                                                      ? colors.primaryContainer
                                                      : colors.surface,
                                                  borderRadius: BorderRadius.circular(
                                                      15)),
                                              child: SelectableText(message.content,
                                                  style: TextStyle(
                                                      color: colors.onSurface,
                                                      fontSize: 13,
                                                      height: 1.7))))),
                                if (_busy)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(children: [
                                        const SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 1.5)),
                                        const SizedBox(width: 8),
                                        Text('正在听你说…',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: colors.primary)),
                                      ])),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_error!,
                                                style: TextStyle(
                                                    color: colors.error,
                                                    fontSize: 12,
                                                    height: 1.5)),
                                            if (_failedText != null)
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _send(
                                                          _failedText!,
                                                          retry: true),
                                                  child: const Text('重试')),
                                          ])),
                              ])))),
              SizedBox(height: compact ? 6 : 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        key: const Key('study-draft'),
                        controller: _draft,
                        focusNode: _draftFocus,
                        autofocus: true,
                        minLines: 1,
                        maxLines: compact ? 1 : 3,
                        maxLength: 2000,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                            hintText: '想说什么，我听着…', counterText: ''),
                        onSubmitted: (text) => _send(text, fromDraft: true))),
                const SizedBox(width: 6),
                IconButton.filled(
                    tooltip: '发送',
                    onPressed: _busy
                        ? null
                        : () => _send(_draft.text, fromDraft: true),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 20)),
              ]),
            ])),
      );
    });
  }
}
