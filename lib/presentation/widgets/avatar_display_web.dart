import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

final poseVersionProvider = StateProvider<int>((ref) => 0);

enum Emotion {
  happy, shy, angry, sad, surprised, neutral,
}

const Map<Emotion, String> emotionExprNames = {
  Emotion.happy: 'happy', Emotion.shy: 'shy',
  Emotion.angry: 'angry', Emotion.sad: 'sad',
  Emotion.surprised: 'surprised', Emotion.neutral: 'neutral',
};

const Map<Emotion, String> emotionToBodyLang = {
  Emotion.happy: 'happy', Emotion.shy: 'shy',
  Emotion.angry: 'angry', Emotion.sad: 'sad',
  Emotion.surprised: 'surprised', Emotion.neutral: 'neutral',
};

class AvatarDisplay extends StatefulWidget {
  final String characterName;
  final Emotion currentEmotion;
  final VoidCallback? onTap;
  final int poseVersion;

  const AvatarDisplay({
    super.key,
    required this.characterName,
    this.currentEmotion = Emotion.happy,
    this.onTap,
    this.poseVersion = 0,
  });

  @override
  State<AvatarDisplay> createState() => _AvatarDisplayState();
}

class _AvatarDisplayState extends State<AvatarDisplay> {
  bool _ready = false;
  bool _loadFailed = false;
  String _lastError = '';
  String _viewId = '';
  html.IFrameElement? _iframe;

  static const _charModels = {
    '温柔学姐': 'senpai.vrm', '活泼青梅': 'genki.vrm',
    '傲娇同桌': 'tsundere.vrm', '知性御姐': 'oneesan.vrm',
    '治愈邻家': 'iyashi.vrm', '拉姆': 'ram.vrm', '蕾姆': 'rem.vrm',
  };

  @override
  void initState() {
    super.initState();
    _initVRM();
  }

  Future<void> _initVRM() async {
    try {
      // Create unique view ID
      _viewId = 'vrm-viewer-${DateTime.now().millisecondsSinceEpoch}';

      // Create iframe element - use relative path from web server root
      _iframe = html.IFrameElement()
        ..src = 'assets/assets/web/vrm_viewer.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';

      // Register the view
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _iframe!,
      );

      // Listen for messages from the iframe
      html.window.onMessage.listen((event) {
        if (event.data == 'vrm_loaded') {
          setState(() {
            _ready = true;
            _loadFailed = false;
          });
        } else if (event.data == 'vrm_ready') {
          // Load the model - use relative path from web server root
          final modelFile = _charModels[widget.characterName] ?? 'senpai.vrm';
          _iframe?.contentWindow?.postMessage(
            'loadModel("assets/assets/models/$modelFile")',
            '*',
          );
        } else if (event.data.toString().startsWith('vrm_error:')) {
          setState(() {
            _loadFailed = true;
            _lastError = event.data.toString();
          });
        }
      });

      setState(() {});
    } catch (e) {
      setState(() {
        _loadFailed = true;
        _lastError = e.toString();
      });
    }
  }

  @override
  void didUpdateWidget(AvatarDisplay old) {
    super.didUpdateWidget(old);
    if (old.characterName != widget.characterName) {
      _reloadModel();
      return;
    }
    if (old.poseVersion != widget.poseVersion && _ready) {
      _iframe?.contentWindow?.postMessage('randomPose()', '*');
    }
    if (old.currentEmotion != widget.currentEmotion && _ready) {
      final e = emotionToBodyLang[widget.currentEmotion] ?? 'neutral';
      _iframe?.contentWindow?.postMessage(
        "setExpression('_emotion','$e')",
        '*',
      );
    }
  }

  Future<void> _reloadModel() async {
    setState(() {
      _ready = false;
      _loadFailed = false;
    });
    final m = _charModels[widget.characterName] ?? 'senpai.vrm';
    _iframe?.contentWindow?.postMessage(
      'loadModel("assets/assets/models/$m")',
      '*',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 300, height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0F3), Color(0xFFFFDEE9), Color(0xFFE8E0F0)],
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF69B4).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(fit: StackFit.expand, children: [
            // VRM viewer iframe
            if (_viewId.isNotEmpty)
              HtmlElementView(viewType: _viewId),
            // Loading indicator
            if (!_ready && !_loadFailed)
              const Center(child: CircularProgressIndicator(color: Color(0xFFFF69B4))),
            // Error indicator
            if (_loadFailed)
              Center(child: Padding(padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                  const SizedBox(height: 8),
                  Text(widget.characterName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                  if (_lastError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_lastError.replaceFirst('vrm_error:', ''), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
                  ],
                ]),
              )),
          ]),
        ),
      ),
    );
  }
}
