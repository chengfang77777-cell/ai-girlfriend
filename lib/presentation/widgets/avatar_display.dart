import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../../domain/audio_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

// Conditional import for webview
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart';

final poseVersionProvider = StateProvider<int>((ref) => 0);

enum Emotion {
  happy,
  shy,
  angry,
  sad,
  surprised,
  neutral,
  refuse,
  thankful,
}

const Map<Emotion, String> emotionExprNames = {
  Emotion.happy: 'happy',
  Emotion.shy: 'shy',
  Emotion.angry: 'angry',
  Emotion.sad: 'sad',
  Emotion.surprised: 'surprised',
  Emotion.neutral: 'neutral',
  Emotion.refuse: 'refuse',
  Emotion.thankful: 'thankful',
};

const Map<Emotion, String> emotionToBodyLang = {
  Emotion.happy: 'happy',
  Emotion.shy: 'shy',
  Emotion.angry: 'angry',
  Emotion.sad: 'sad',
  Emotion.surprised: 'surprised',
  Emotion.neutral: 'neutral',
  Emotion.refuse: 'refuse',
  Emotion.thankful: 'thankful',
};

class AvatarDisplay extends StatefulWidget {
  final String characterName;
  final String? modelPath;
  final Emotion currentEmotion;
  final VoidCallback? onTap;
  final int poseVersion;
  final String? backgroundId;

  /// Action label (wave, nod, clap, …) that the AI returned with its reply.
  /// When this changes we play the matching motion clip in the VRM viewer.
  final String? action;
  final VoidCallback? onAudioStarted;

  const AvatarDisplay({
    super.key,
    required this.characterName,
    this.modelPath,
    this.currentEmotion = Emotion.neutral,
    this.onTap,
    this.poseVersion = 0,
    this.backgroundId,
    this.action,
    this.onAudioStarted,
  });

  @override
  State<AvatarDisplay> createState() => _AvatarDisplayState();
}

class _AvatarDisplayState extends State<AvatarDisplay> {
  // For Windows
  WebviewController? _windowsCtrl;

  // For mobile
  WebViewController? _mobileCtrl;

  AudioPlayback? _playback;
  int _audioGeneration = 0;

  Future<void> _runScript(String script) async {
    if (_windowsCtrl != null) {
      await _windowsCtrl!
          .executeScript(script)
          .timeout(const Duration(seconds: 5));
    } else if (_mobileCtrl != null) {
      await _mobileCtrl!
          .runJavaScript(script)
          .timeout(const Duration(seconds: 5));
    } else {
      throw StateError('播放器尚未就绪，请等待角色加载后重试');
    }
  }

  Future<void> stopAudio() async {
    ++_audioGeneration;
    _playback?.cancel();
    _playback = null;
    if (_windowsCtrl != null || _mobileCtrl != null) {
      await _runScript('window.stopCurrentAudio?.();');
    }
  }

  Future<void> playAudio(Uint8List bytes, {String? reactionId}) async {
    final generation = ++_audioGeneration;
    _playback?.cancel();
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!_vrmReady &&
        mounted &&
        !_loadFailed &&
        generation == _audioGeneration &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || generation != _audioGeneration) return;
    if (!_vrmReady) throw StateError('角色播放器加载未完成，请加载后重试语音');
    final directory = await getApplicationDocumentsDirectory();
    if (!mounted || generation != _audioGeneration) return;
    final id = '${DateTime.now().microsecondsSinceEpoch}_$generation';
    final file = File('${directory.path}/vrm/speech_$id.wav');
    AudioPlayback? playback;
    try {
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted || generation != _audioGeneration) return;
      playback = AudioPlayback(id, bytes, onStarted: () {
        if (mounted && generation == _audioGeneration) {
          widget.onAudioStarted?.call();
        }
      });
      _playback = playback;
      // Listen before dispatch: events can arrive while executeScript is pending.
      await Future.wait<void>([
        playback.done,
        _runScript(
            'window.playSpeech(${jsonEncode('http://127.0.0.1:$_port/speech_$id.wav')},${jsonEncode(id)},${jsonEncode(reactionId)});'),
      ], eagerError: true);
    } finally {
      playback?.cancel();
      if (identical(_playback, playback)) _playback = null;
      try {
        if (mounted) {
          await _runScript('window.stopAudioRequest?.(${jsonEncode(id)});');
        }
      } catch (_) {/* The original playback error is reported to the caller. */}
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  bool _vrmReady = false;
  bool _loadFailed = false;
  String _lastError = '';
  static HttpServer? _server;
  static int _port = 0;
  StreamSubscription<dynamic>? _webMessageSub;

  /// Public accessors so parent can send JS commands to the WebView
  WebviewController? get windowsController => _windowsCtrl;
  WebViewController? get mobileController => _mobileCtrl;

  static const _charModels = {
    '温柔学姐': 'senpai.vrm',
    '活泼青梅': 'genki.vrm',
    '傲娇同桌': 'tsundere.vrm',
    '知性御姐': 'oneesan.vrm',
    '治愈邻家': 'iyashi.vrm',
    '拉姆': 'ram.vrm',
    '蕾姆': 'rem.vrm',
  };
  static const _jsFiles = [
    'three.module.js',
    'three-vrm.module.js',
    'three-vrm-animation.module.js',
    'GLTFLoader.js',
    'OrbitControls.js',
    'BufferGeometryUtils.js',
  ];
  static const _vrmaFiles = [
    'angry.vrma',
    'clapping.vrma',
    'happy idle.vrma',
    'Head Shake idle.vrma',
    'idle.vrma',
    'sad idle.vrma',
    'Shaking Head No.vrma',
    'Standing Greeting.vrma',
    'Thankful.vrma',
    'Yawn.vrma',
  ];

  @override
  void initState() {
    super.initState();
    _initVRM();
  }

  Future<void> _initVRM() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vrmDir = Directory('${appDir.path}/vrm');
      if (!await vrmDir.exists()) await vrmDir.create(recursive: true);

      debugPrint('VRM: Initializing VRM viewer...');

      // 停掉旧服务器，避免目录冲突
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
        debugPrint('VRM: Closed old server');
      }

      // 只复制不存在的模型文件（避免每次启动都覆盖几十MB的文件）
      for (final e in _charModels.entries) {
        final target = File('${vrmDir.path}/${e.value}');
        if (!await target.exists()) {
          debugPrint('VRM: Copying model: ${e.value}');
          final data = await rootBundle.load('assets/models/${e.value}');
          await target.writeAsBytes(data.buffer.asUint8List());
        }
      }
      // 只复制不存在的 JS 文件
      final jsDir = Directory('${vrmDir.path}/js');
      if (!await jsDir.exists()) await jsDir.create(recursive: true);
      for (final f in _jsFiles) {
        final target = File('${jsDir.path}/$f');
        if (!await target.exists()) {
          debugPrint('VRM: Copying JS file: $f');
          final data = await rootBundle.load('assets/web/js/$f');
          await target.writeAsBytes(data.buffer.asUint8List());
        }
      }

      // Application-owned code must be refreshed so installed builds use new tuning.
      for (final name in ['lip-sync.js', 'emotion-driver.js']) {
        final data = await rootBundle.load('assets/web/js/$name');
        await File('${jsDir.path}/$name')
            .writeAsBytes(data.buffer.asUint8List());
      }

      // 只复制不存在的 VRMA 动画文件
      final animDir = Directory('${vrmDir.path}/animations');
      if (!await animDir.exists()) await animDir.create(recursive: true);
      for (final f in _vrmaFiles) {
        final target = File('${animDir.path}/$f');
        if (!await target.exists()) {
          debugPrint('VRM: Copying VRMA file: $f');
          final data = await rootBundle.load('assets/animations/$f');
          await target.writeAsBytes(data.buffer.asUint8List());
        }
      }
      // 复制 wlipsync-processor.js (lip-sync AudioWorklet)
      final lipsyncFile = File('assets/web/js/wlipsync-processor.js');
      if (await lipsyncFile.exists()) {
        final data =
            await rootBundle.load('assets/web/js/wlipsync-processor.js');
        await File('${jsDir.path}/wlipsync-processor.js')
            .writeAsBytes(data.buffer.asUint8List());
        debugPrint('VRM: Copied wlipsync-processor.js');
      }
      // 复制 services 目录 (gesture-engine.js, ws-blendshape-client.js)
      final servicesDir = Directory('${vrmDir.path}/services');
      if (!await servicesDir.exists()) {
        await servicesDir.create(recursive: true);
      }
      for (final svcName in ['gesture-engine.js', 'ws-blendshape-client.js']) {
        try {
          final data = await rootBundle.load('assets/web/services/$svcName');
          await File('${servicesDir.path}/$svcName')
              .writeAsBytes(data.buffer.asUint8List());
          debugPrint('VRM: Copied service: $svcName');
        } catch (e) {
          debugPrint('VRM: Service file not found: $svcName ($e)');
        }
      }
      // 强制覆盖 HTML
      final html = await rootBundle.loadString('assets/web/vrm_viewer.html');
      await File('${vrmDir.path}/viewer.html').writeAsString(html);
      debugPrint('VRM: All files copied');

      // Start server
      if (_server == null) {
        _server = await io.serve(
          (request) async {
            final p = '${vrmDir.path}/${request.url.pathSegments.join('/')}';
            final f = File(p);
            debugPrint('VRM Server: Request for: ${request.url.path}');
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              final mime = p.endsWith('.vrm')
                  ? 'application/octet-stream'
                  : p.endsWith('.vrma')
                      ? 'application/octet-stream'
                      : p.endsWith('.js')
                          ? 'application/javascript'
                          : p.endsWith('.html')
                              ? 'text/html; charset=utf-8'
                              : p.endsWith('.wav')
                                  ? 'audio/wav'
                                  : p.endsWith('.mp3')
                                      ? 'audio/mpeg'
                                      : 'text/plain';
              return shelf.Response.ok(bytes, headers: {
                'Content-Type': mime,
                'Access-Control-Allow-Origin': '*',
                'Cache-Control': 'no-store',
              });
            }
            debugPrint('VRM Server: File not found: $p');
            return shelf.Response.notFound('');
          },
          InternetAddress('127.0.0.1'),
          0,
          shared: true,
        );
        _port = _server!.port;
        debugPrint('VRM: Server started on port: $_port');
      }

      // 优先使用 modelPath，否则按角色名查找，最后默认 senpai
      String modelFile;
      if (widget.modelPath != null && widget.modelPath!.isNotEmpty) {
        final extracted = widget.modelPath!.split('/').last;
        modelFile = extracted.isNotEmpty
            ? extracted
            : (_charModels[widget.characterName] ?? 'senpai.vrm');
      } else {
        modelFile = _charModels[widget.characterName] ?? 'senpai.vrm';
      }
      final base = 'http://127.0.0.1:$_port';

      debugPrint('VRM: Loading viewer from: $base/viewer.html');
      debugPrint('VRM: Model file: $modelFile');

      if (Platform.isWindows) {
        // Use webview_windows for Windows
        try {
          _windowsCtrl = WebviewController();
          await _windowsCtrl!.initialize();
          debugPrint('VRM: Windows WebView initialized');
        } catch (e) {
          debugPrint('VRM: WebView init failed: $e');
          setState(() {
            _loadFailed = true;
            _lastError = 'WebView init failed: $e';
          });
          return;
        }

        _webMessageSub = _windowsCtrl!.webMessage.listen((message) {
          debugPrint('VRM: Message from Windows WebView: $message');
          if (message is String) _playback?.handle(message);
          if (message == 'vrm_loaded') {
            debugPrint('VRM: Model loaded successfully!');
            setState(() {
              _vrmReady = true;
              _loadFailed = false;
            });
            _runScript(
                "setExpression('_emotion','${widget.currentEmotion.name}')");
            // 设置背景
            if (widget.backgroundId != null) {
              _windowsCtrl
                  ?.executeScript('setBackground("${widget.backgroundId}")');
            }
          } else if (message == 'vrm_ready') {
            debugPrint('VRM: WebView ready, loading model: $base/$modelFile');
            // Set base URL in viewer
            _windowsCtrl!.executeScript('window._vrmBaseUrl = "$base";');
            _windowsCtrl!.executeScript(
                'window._characterName="${widget.characterName}";loadModel("$base/$modelFile")');
            // Add timeout to prevent infinite loading
            Future.delayed(const Duration(seconds: 15), () {
              if (!_vrmReady && !_loadFailed && mounted) {
                debugPrint('VRM: Loading timeout');
                setState(() {
                  _loadFailed = true;
                  _lastError = '加载超时';
                });
              }
            });
          } else if (message.startsWith('vrm_error:')) {
            debugPrint('VRM: Error: $message');
            setState(() {
              _loadFailed = true;
              _lastError = message;
            });
          }
        });

        await _windowsCtrl!.loadUrl('$base/viewer.html?wheelRouting=flutter');
      } else {
        // Use webview_flutter for mobile
        _mobileCtrl = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..enableZoom(true)
          ..setNavigationDelegate(NavigationDelegate(
            onWebResourceError: (error) {
              debugPrint(
                  'VRM WebView Error: ${error.description} (${error.errorCode})');
            },
            onPageFinished: (url) {
              debugPrint('VRM WebView Page finished: $url');
            },
          ))
          ..addJavaScriptChannel('flutter', onMessageReceived: (msg) {
            debugPrint('VRM: Message from Mobile WebView: ${msg.message}');
            _playback?.handle(msg.message);
            if (msg.message == 'vrm_loaded') {
              debugPrint('VRM: Model loaded successfully!');
              setState(() {
                _vrmReady = true;
                _loadFailed = false;
              });
              _runScript(
                  "setExpression('_emotion','${widget.currentEmotion.name}')");
              // 设置背景
              if (widget.backgroundId != null) {
                _mobileCtrl
                    ?.runJavaScript('setBackground("${widget.backgroundId}")');
              }
            } else if (msg.message == 'vrm_ready') {
              debugPrint('VRM: WebView ready, loading model: $base/$modelFile');
              _mobileCtrl?.runJavaScript(
                  'window._characterName="${widget.characterName}";loadModel("$base/$modelFile")');
              // Add timeout to prevent infinite loading
              Future.delayed(const Duration(seconds: 15), () {
                if (!_vrmReady && !_loadFailed && mounted) {
                  debugPrint('VRM: Loading timeout');
                  setState(() {
                    _loadFailed = true;
                    _lastError = '加载超时';
                  });
                }
              });
            } else if (msg.message.startsWith('vrm_error:')) {
              debugPrint('VRM: Error: ${msg.message}');
              setState(() {
                _loadFailed = true;
                _lastError = msg.message;
              });
            }
          })
          ..loadRequest(Uri.parse('$base/viewer.html'));

        // 允许音频自动播放（口型/语音同步），无需用户手势触发
        final platformCtrl = _mobileCtrl!.platform;
        if (platformCtrl is AndroidWebViewController) {
          platformCtrl.setMediaPlaybackRequiresUserGesture(false);
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('VRM: Error initializing: $e');
      setState(() {
        _loadFailed = true;
        _lastError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    ++_audioGeneration;
    _playback?.cancel();
    _webMessageSub?.cancel();
    _windowsCtrl?.dispose();
    // webview_flutter 的 WebViewController 无公开 dispose，随 widget 销毁即可
    // 关闭本地 HTTP 服务器（单实例场景；重新进入页面时 _initVRM 会重新创建）
    if (_server != null) {
      _server!.close(force: true);
      _server = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AvatarDisplay old) {
    super.didUpdateWidget(old);
    if (old.characterName != widget.characterName) {
      _reloadModel();
      return;
    }
    // 移除随机换动作功能 - 使用VRMA待机动画
    // if (old.poseVersion != widget.poseVersion && _vrmReady) {
    //   if (Platform.isWindows) {
    //     _windowsCtrl?.executeScript('randomPose()');
    //   } else {
    //     _mobileCtrl?.runJavaScript('randomPose()');
    //   }
    // }
    if (old.currentEmotion != widget.currentEmotion && _vrmReady) {
      final e = emotionToBodyLang[widget.currentEmotion] ?? 'neutral';
      if (Platform.isWindows) {
        _windowsCtrl?.executeScript("setExpression('_emotion','$e')");
      } else {
        _mobileCtrl?.runJavaScript("setExpression('_emotion','$e')");
      }
    }
    // 背景变化时立即应用
    if (old.backgroundId != widget.backgroundId &&
        _vrmReady &&
        widget.backgroundId != null) {
      if (Platform.isWindows) {
        _windowsCtrl?.executeScript('setBackground("${widget.backgroundId}")');
      } else {
        _mobileCtrl?.runJavaScript('setBackground("${widget.backgroundId}")');
      }
    }
  }

  Future<void> _reloadModel() async {
    await stopAudio();
    if (!mounted) return;
    setState(() {
      _vrmReady = false;
      _loadFailed = false;
    });
    String m;
    if (widget.modelPath != null && widget.modelPath!.isNotEmpty) {
      final extracted = widget.modelPath!.split('/').last;
      m = extracted.isNotEmpty
          ? extracted
          : (_charModels[widget.characterName] ?? 'senpai.vrm');
    } else {
      m = _charModels[widget.characterName] ?? 'senpai.vrm';
    }
    final url = 'http://127.0.0.1:$_port/$m';

    if (Platform.isWindows) {
      _windowsCtrl?.executeScript(
          'window._characterName="${widget.characterName}";loadModel("$url")');
    } else {
      _mobileCtrl?.runJavaScript(
          'window._characterName="${widget.characterName}";loadModel("$url")');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0F3), Color(0xFFFFDEE9), Color(0xFFE8E0F0)],
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          // WebView for Windows
          if (Platform.isWindows && _windowsCtrl != null)
            Webview(_windowsCtrl!),
          // WebView for mobile
          if (!Platform.isWindows && _mobileCtrl != null)
            WebViewWidget(controller: _mobileCtrl!),
          // Loading indicator
          if (!_vrmReady && !_loadFailed)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF69B4))),
          // Error indicator
          if (_loadFailed)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.white54),
                const SizedBox(height: 8),
                Text(widget.characterName,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                if (_lastError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_lastError.replaceFirst('vrm_error:', ''),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10),
                      textAlign: TextAlign.center),
                ],
              ]),
            )),
        ]),
      ),
    );
  }
}
