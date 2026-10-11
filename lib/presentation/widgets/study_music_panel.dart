import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/theme.dart';
import 'study_music_controls.dart';

/// A separate official music page; opening it does not change the study clock.
class StudyMusicPanel extends StatefulWidget {
  const StudyMusicPanel(
      {super.key,
      required this.onClose,
      this.minimized = false,
      this.onToggleMinimized});

  final VoidCallback onClose;
  final bool minimized;
  final VoidCallback? onToggleMinimized;

  @override
  State<StudyMusicPanel> createState() => _StudyMusicPanelState();
}

class _StudyMusicPanelState extends State<StudyMusicPanel> {
  static const _homeUrl = 'https://music.163.com/st/webplayer';
  WebviewController? _controller;
  Future<void>? _initialization;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _loadingDeadline;
  Timer? _playbackPoll;
  MusicPlaybackState _playback = const MusicPlaybackState();
  bool _readingPlayback = false;
  bool _playbackReadFailed = false;
  bool _commandBusy = false;
  int _navigationGeneration = 0;
  int _commandId = 0;
  Completer<bool>? _pendingCommand;
  String? _controlHint;
  bool _ready = false;
  bool _loading = true;
  bool _canGoBack = false;
  bool _closed = false;
  String? _error;
  String _currentUrl = _homeUrl;

  bool _owns(WebviewController controller) =>
      mounted && !_closed && identical(_controller, controller);

  bool get _isMusicPage {
    final uri = Uri.tryParse(_currentUrl);
    return uri?.scheme == 'https' && uri?.host == 'music.163.com';
  }

  Future<void> _refreshPlayback() async {
    final controller = _controller;
    if (_error != null ||
        !_ready ||
        _loading ||
        _readingPlayback ||
        !_isMusicPage ||
        controller == null ||
        !_owns(controller)) return;
    final generation = _navigationGeneration;
    _readingPlayback = true;
    try {
      final result = await controller
          .executeScript(
            'window.__studyMusicBridge?.snapshot() ?? null',
          )
          .timeout(const Duration(seconds: 3));
      if (!_owns(controller) ||
          generation != _navigationGeneration ||
          _error != null) return;
      setState(() {
        _playbackReadFailed = false;
        _playback = result is Map
            ? MusicPlaybackState.fromMap(result)
            : const MusicPlaybackState();
      });
    } catch (_) {
      if (_owns(controller) && generation == _navigationGeneration) {
        setState(() {
          _playback = const MusicPlaybackState();
          _playbackReadFailed = true;
        });
      }
    } finally {
      if (generation == _navigationGeneration) _readingPlayback = false;
    }
  }

  Future<void> _musicCommand(String action, [Object? value]) async {
    final controller = _controller;
    if (_error != null ||
        _commandBusy ||
        !_ready ||
        _loading ||
        !_isMusicPage ||
        controller == null ||
        !_owns(controller)) return;
    final generation = _navigationGeneration;
    final id = ++_commandId;
    final pending = Completer<bool>();
    _pendingCommand = pending;
    setState(() {
      _commandBusy = true;
      _controlHint = null;
    });
    var ok = false;
    try {
      // WebView2 ExecuteScript does not await JavaScript promises. The result
      // arrives via a correlated webMessage after the page's handler finishes.
      await controller.executeScript('''(() => {
        const report = ok => window.chrome.webview.postMessage({type:'studyMusicCommand',id:$id,ok});
        Promise.resolve(window.__studyMusicBridge?.command(${jsonEncode(action)},${jsonEncode(value)}))
          .then(result => report(result?.ok === true)).catch(() => report(false));
      })()''').timeout(const Duration(seconds: 3));
      ok = await pending.future.timeout(const Duration(seconds: 4));
    } catch (_) {
      ok = false;
    }
    if (!_owns(controller) || generation != _navigationGeneration) return;
    if (identical(_pendingCommand, pending)) _pendingCommand = null;
    setState(() {
      _commandBusy = false;
      _controlHint = ok ? null : '操作未完成，请展开网易云操作';
    });
    await _refreshPlayback();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      setState(() {
        _loading = false;
        _error = '内嵌音乐目前支持 Windows 桌面版。';
      });
      return;
    }
    _detach();
    final controller = WebviewController();
    _controller = controller;
    setState(() {
      _ready = false;
      _loading = true;
      _error = null;
      _canGoBack = false;
      _currentUrl = _homeUrl;
    });
    final initialization = controller.initialize();
    _initialization = initialization;
    try {
      await initialization.timeout(const Duration(seconds: 20));
      if (!_owns(controller)) return;
      _subscriptions.addAll([
        controller.loadingState.listen((state) {
          if (!_owns(controller)) return;
          if (state == LoadingState.loading) {
            _beginLoading(controller);
          } else if (state == LoadingState.navigationCompleted) {
            _loadingDeadline?.cancel();
            setState(() {
              _loading = false;
              _error = null;
            });
            unawaited(_refreshPlayback());
          }
        }),
        controller.onLoadError.listen((_) {
          if (_owns(controller)) {
            _showError('网页暂时无法加载，请检查网络后重新连接。');
          }
        }),
        controller.historyChanged.listen((history) {
          if (_owns(controller)) {
            setState(() => _canGoBack = history.canGoBack);
          }
        }),
        controller.url.listen((url) {
          if (_owns(controller)) {
            setState(() {
              _currentUrl = url;
              if (!_isMusicPage) _playback = const MusicPlaybackState();
            });
          }
        }),
        controller.webMessage.listen((message) {
          if (!_owns(controller) ||
              !_isMusicPage ||
              message is! Map ||
              message['type'] != 'studyMusicCommand' ||
              message['id'] != _commandId) return;
          final pending = _pendingCommand;
          if (pending != null && !pending.isCompleted) {
            pending.complete(message['ok'] == true);
          }
        }),
      ]);
      final bridge =
          await rootBundle.loadString('assets/web/js/study-music-bridge.js');
      if (!_owns(controller)) return;
      await controller.addScriptToExecuteOnDocumentCreated(bridge);
      if (!_owns(controller)) return;
      await controller.setBackgroundColor(Colors.white);
      if (!_owns(controller)) return;
      await controller
          .setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      if (!_owns(controller)) return;
      await controller.setZoomFactor(0.8);
      if (!_owns(controller)) return;
      setState(() => _ready = true);
      _beginLoading(controller);
      await controller.loadUrl(_homeUrl);
      if (!_owns(controller)) return;
      _playbackPoll = Timer.periodic(
          const Duration(seconds: 1), (_) => unawaited(_refreshPlayback()));
    } catch (_) {
      if (_owns(controller)) {
        _showError('音乐页面启动失败，请重试。若持续失败，请检查网络和 WebView2 运行时。');
      }
    }
  }

  void _beginLoading(WebviewController controller) {
    _loadingDeadline?.cancel();
    setState(() {
      _navigationGeneration++;
      _readingPlayback = false;
      _playback = const MusicPlaybackState();
      _playbackReadFailed = false;
      _controlHint = null;
      _commandBusy = false;
      if (_pendingCommand?.isCompleted == false) {
        _pendingCommand!.complete(false);
      }
      _pendingCommand = null;
      _loading = true;
      _error = null;
    });
    _loadingDeadline = Timer(const Duration(seconds: 30), () {
      if (_owns(controller)) {
        _showError('页面加载时间较长，可以重新连接后再试。');
      }
    });
  }

  void _showError(String message) {
    _loadingDeadline?.cancel();
    setState(() {
      _loading = false;
      _error = message;
      _playback = const MusicPlaybackState();
    });
  }

  Future<void> _navigate(
      Future<void> Function(WebviewController) action) async {
    final controller = _controller;
    if (!_ready || controller == null || !_owns(controller)) return;
    _beginLoading(controller);
    try {
      await action(controller);
    } catch (_) {
      if (_owns(controller)) _showError('无法打开页面，请重新连接。');
    }
  }

  void _detach() {
    _loadingDeadline?.cancel();
    _playbackPoll?.cancel();
    _navigationGeneration++;
    _readingPlayback = false;
    _commandBusy = false;
    _playback = const MusicPlaybackState();
    if (_pendingCommand?.isCompleted == false) _pendingCommand!.complete(false);
    _pendingCommand = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final controller = _controller;
    final initialization = _initialization;
    _controller = null;
    _initialization = null;
    if (controller != null && initialization != null) {
      unawaited(_release(controller, initialization));
    }
  }

  Future<void> _release(
    WebviewController controller,
    Future<void> initialization,
  ) async {
    // Await the real native initialization, even if the visible wait timed out.
    // webview_windows cannot dispose a controller whose initialization failed.
    try {
      await initialization;
    } catch (_) {
      return;
    }
    try {
      // Destroying the native WebView also stops media, including iframe audio.
      await controller.dispose();
    } catch (error) {
      debugPrint('Music WebView cleanup failed: $error');
    }
  }

  void _close() {
    if (_closed) return;
    setState(() {
      _closed = true;
      _ready = false;
    });
    _detach();
    widget.onClose();
  }

  @override
  void dispose() {
    _closed = true;
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(_currentUrl)?.host;
    if (widget.minimized) {
      return StudyMusicControls(
        state: _playback,
        busy: _commandBusy,
        status: _error ??
            (_loading
                ? '正在连接网易云音乐…'
                : _controlHint ??
                    (_playbackReadFailed ? '暂时无法读取播放状态，请展开音乐操作' : null)),
        onCommand: (action) => unawaited(_musicCommand(action)),
        onVolume: (value) => unawaited(_musicCommand('volume', value)),
        onSeek: (value) => unawaited(_musicCommand(
            'seek', {'seconds': value, 'trackId': _playback.trackId})),
        onExpand: widget.onToggleMinimized,
        onClose: _close,
      );
    }
    return Material(
      color: AppTheme.bgCardLight,
      elevation: 8,
      shadowColor: AppTheme.shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('学习音乐',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      )),
                ),
                if (widget.onToggleMinimized != null)
                  IconButton(
                      tooltip: '收起音乐，继续陪学',
                      onPressed: widget.onToggleMinimized,
                      icon: const Icon(Icons.minimize_rounded)),
                IconButton(
                  tooltip: '关闭音乐',
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Container(
            color: AppTheme.primarySoft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回上一页',
                  onPressed: _ready && _canGoBack
                      ? () => _navigate((c) => c.goBack())
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 19),
                ),
                IconButton(
                  tooltip: '网易云首页',
                  onPressed: _ready
                      ? () => _navigate((c) => c.loadUrl(_homeUrl))
                      : null,
                  icon: const Icon(Icons.home_outlined, size: 20),
                ),
                IconButton(
                  tooltip: '刷新音乐',
                  onPressed: _ready ? () => _navigate((c) => c.reload()) : null,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    host?.isNotEmpty == true ? host! : '网易云音乐',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child:
                _loading && !_closed ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready && _controller != null && !_closed)
                  KeyedSubtree(
                    key: ObjectKey(_controller),
                    child: Webview(_controller!,
                        permissionRequested: (_, __, ___) =>
                            WebviewPermissionDecision.deny),
                  ),
                if ((!_ready || _error != null) && !_closed)
                  ColoredBox(
                    color: AppTheme.bgLight,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_error == null)
                              const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else
                              const Icon(Icons.wifi_off_rounded,
                                  size: 30, color: AppTheme.textSecondary),
                            const SizedBox(height: 14),
                            Text(_error ?? '正在连接网易云音乐…',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                            if (_error != null &&
                                !kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.windows) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _connect,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重新连接'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '网易云官方网页 · 登录及可播放曲目以官方页面为准 · 关闭面板会停止音乐',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
        ],
      ),
    );
  }
}
