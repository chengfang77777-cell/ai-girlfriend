// Native bridge verification against our own local fixture, never a remote site.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/presentation/widgets/study_music_controls.dart';
import 'windows_chat_probe.dart' show findElement, check, until;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final output = File('${docs.path}/windows-music-probe.log');
  await output.writeAsString('Native local music bridge verification\n');
  Future<void> log(String message) =>
      output.writeAsString('$message\n', mode: FileMode.append, flush: true);
  var code = 0;
  try {
    await verifyStudyMusicBridge(docs, log);
  } catch (error, stack) {
    code = 1;
    await log('FAIL: $error\n$stack');
  }
  exit(code);
}

Future<void> verifyStudyMusicBridge(
    Directory docs, Future<void> Function(String) log) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final controller = WebviewController();
  final mini = ValueNotifier(false);
  final playback = ValueNotifier(const MusicPlaybackState());
  final screen = GlobalKey();
  var initialized = false;
  final wav = Uint8List(44 + 320000);
  final data = ByteData.sublistView(wav);
  void ascii(int offset, String value) =>
      wav.setRange(offset, offset + value.length, asciiEncode(value));
  ascii(0, 'RIFF');
  data.setUint32(4, wav.length - 8, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, 320000, Endian.little);
  server.listen((request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write('''<!doctype html><meta charset="utf-8">
      <button id="start" style="width:200px;height:80px">播放本地静音测试音频</button>
      <input id="volume" type="range" aria-label="音量" min="0" max="1" step="0.01" value="0.6">
      <button id="custom" style="position:absolute;left:8px;top:100px;width:200px;height:60px">自定义网页控件</button>
      <div id="playlist" style="position:absolute;left:420px;top:20px;width:220px;height:180px;overflow:auto">
        <div style="height:1800px;width:800px;background:linear-gradient(white,lightgreen)">滚轮测试歌单</div>
      </div>
      <iframe id="frame" style="position:absolute;left:700px;top:20px;width:220px;height:180px;border:0"
        srcdoc='<div style="height:1800px;width:800px">内嵌歌单</div>'></iframe>
      <script>
      const player = new Audio('data:audio/wav;base64,${base64Encode(wav)}');
      player.loop = true; player.volume = .6;
      let track = 1;
      window._wheelEvents = [];
      document.addEventListener('wheel', e => window._wheelEvents.push({x:e.clientX,y:e.clientY,trusted:e.isTrusted}), true);
      document.querySelector('#playlist').addEventListener('wheel', e => {
        if (window._blockWheel) e.preventDefault();
      }, {passive:false});
      let savedVolume = .6;
      document.querySelector('#volume').oninput = e => {savedVolume = Number(e.target.value);player.volume = savedVolume;};
      document.querySelector('#custom').onclick = () => setTimeout(() => {
        savedVolume = .7; player.volume = .7; document.querySelector('#volume').value = .7;
      }, 1000);
      const update = () => {navigator.mediaSession.metadata = new MediaMetadata({title:'测试歌曲 ' + track,artist:'本地测试歌手'});};
      update();
      navigator.mediaSession.setActionHandler('nexttrack', () => {track++;update();player.volume=savedVolume;player.play();setTimeout(() => player.volume=savedVolume, 80);});
      navigator.mediaSession.setActionHandler('previoustrack', () => {track--;update();});
      navigator.mediaSession.setActionHandler('play', () => player.play());
      navigator.mediaSession.setActionHandler('pause', () => player.pause());
      document.querySelector('#start').onclick = () => player.play();
      </script>''');
    await request.response.close();
  });
  var sequence = 0;
  Completer<bool>? pending;
  final subscription = controller.webMessage.listen((message) {
    if (message is Map &&
        message['type'] == 'nativeMusicProbe' &&
        message['id'] == sequence &&
        pending != null &&
        !pending!.isCompleted) {
      pending!.complete(message['ok'] == true);
    }
  });
  Future<Map> snapshot() async =>
      await controller.executeScript('window.__studyMusicBridge.snapshot()')
          as Map;
  Future<void> command(String action, [Object? value]) async {
    final id = ++sequence, result = Completer<bool>();
    pending = result;
    try {
      await controller.executeScript('''(() => {
        window.__studyMusicBridge.command(${jsonEncode(action)},${jsonEncode(value)}).then(result =>
          window.chrome.webview.postMessage({type:'nativeMusicProbe',id:$id,ok:result.ok}));
      })()''');
      check(await result.future.timeout(const Duration(seconds: 4)),
          'Native music command failed: $action');
      playback.value = MusicPlaybackState.fromMap(await snapshot());
    } finally {
      pending = null;
    }
  }

  try {
    await controller.initialize();
    initialized = true;
    await controller.addScriptToExecuteOnDocumentCreated(
        await rootBundle.loadString('assets/web/js/study-music-bridge.js'));
    runApp(MaterialApp(
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
            key: screen,
            child: Scaffold(
                body: ValueListenableBuilder<bool>(
                    valueListenable: mini,
                    builder: (context, minimized, _) => Stack(children: [
                          if (!minimized)
                            Positioned(
                                left: 32,
                                top: 24,
                                right: 32,
                                bottom: 24,
                                child: Webview(controller, scaleFactor: 1.5)),
                          if (minimized)
                            Positioned(
                                left: 28,
                                bottom: 28,
                                width: 360,
                                height: 208,
                                child: ValueListenableBuilder<
                                        MusicPlaybackState>(
                                    valueListenable: playback,
                                    builder: (context, state, _) =>
                                        StudyMusicControls(
                                            state: state,
                                            onCommand: (action) =>
                                                unawaited(command(action)),
                                            onVolume: (value) => unawaited(
                                                command('volume', value)),
                                            onSeek: (value) => unawaited(
                                                    command('seek', {
                                                  'seconds': value,
                                                  'trackId':
                                                      playback.value.trackId
                                                })),
                                            onExpand: () => mini.value = false,
                                            onClose: () {}))),
                        ]))))));
    await controller.loadUrl('http://127.0.0.1:${server.port}/');
    await until(() async {
      try {
        return (await snapshot())['title'] == '测试歌曲 1';
      } catch (_) {
        return false;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final box =
        findElement((e) => e.widget is Webview).renderObject! as RenderBox;
    final listPoint = box.localToGlobal(const Offset(480, 100));
    // Wheel input itself must carry its location, even without a prior hover.
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        position: listPoint,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, 120)));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await log(
        'Native playlist wheel: ${await controller.executeScript('JSON.stringify(window._wheelEvents)')}');
    check(
        (await controller.executeScript(
                'document.querySelector("#playlist").scrollTop') as num) >
            0,
        'Wheel did not scroll the nested playlist under the pointer');
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        position: listPoint,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(120, 0)));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    check(
        (await controller.executeScript(
                'document.querySelector("#playlist").scrollLeft') as num) >
            0,
        'Horizontal wheel did not scroll the playlist');
    await log(
        'PASS: native vertical and horizontal wheels target the nested playlist');
    await controller.setZoomFactor(.8);
    await controller.executeScript(
        'document.querySelector("#playlist").scrollTop = 0;window._wheelEvents = [];');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final zoomPoint = box.localToGlobal(const Offset(384, 80));
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        position: zoomPoint,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, 120)));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final zoomEvents =
        await controller.executeScript('window._wheelEvents') as List;
    check(
        zoomEvents.length == 1 && (zoomEvents.single as Map)['trusted'] == true,
        'Zoomed wheel was lost, duplicated or bypassed browser input');
    check(
        ((zoomEvents.single as Map)['x'] as num) == 480 &&
            ((zoomEvents.single as Map)['y'] as num) == 100 &&
            (await controller.executeScript(
                    'document.querySelector("#playlist").scrollTop') as num) >
                0,
        '150% DPI and 80% zoom did not target the playlist correctly');
    final beforeBlocked = await controller
        .executeScript('document.querySelector("#playlist").scrollTop');
    await controller.executeScript('window._blockWheel = true;');
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        position: zoomPoint,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, 120)));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    check(
        await controller.executeScript(
                'document.querySelector("#playlist").scrollTop') ==
            beforeBlocked,
        'Page preventDefault did not stop the wheel');
    await controller.executeScript('window._blockWheel = false;');
    final framePoint = box.localToGlobal(const Offset(608, 80));
    GestureBinding.instance.handlePointerEvent(PointerScrollEvent(
        position: framePoint,
        kind: PointerDeviceKind.mouse,
        scrollDelta: const Offset(0, 120)));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    check(
        (await controller.executeScript(
                    'document.querySelector("#frame").contentDocument.scrollingElement.scrollTop')
                as num) >
            0,
        'Wheel did not reach the nested frame');
    await log(
        'PASS: offset panel, 150% DPI, 80% page zoom, trusted wheel, page cancellation and iframe scrolling');
    await controller.setZoomFactor(1);
    final point = box.localToGlobal(const Offset(80, 45));
    GestureBinding.instance.handlePointerEvent(
        PointerHoverEvent(position: point, kind: PointerDeviceKind.mouse));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 91,
        position: point,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 91, position: point, kind: PointerDeviceKind.mouse));
    await until(() async => (await snapshot())['playing'] == true);
    await log('Local audio started through the native WebView pointer path');
    playback.value = MusicPlaybackState.fromMap(await snapshot());
    mini.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    check((await snapshot())['playing'] == true, 'Minimizing stopped playback');
    await command('next');
    check((await snapshot())['title'] == '测试歌曲 2', 'Next did not update title');
    await command('previous');
    check((await snapshot())['title'] == '测试歌曲 1', 'Previous failed');
    await command('volume', .3);
    check(
        ((await snapshot())['volume'] as num) == .3, 'Volume was not applied');
    check(
        await controller.executeScript(
                'Number(document.querySelector("#volume").value)') ==
            .3,
        'Page volume UI not synchronized');
    await command('next');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    check((await snapshot())['volume'] == .3, 'Track reset overwrote volume');
    mini.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final webBox =
        findElement((e) => e.widget is Webview).renderObject! as RenderBox;
    final customPoint = webBox.localToGlobal(const Offset(80, 130));
    GestureBinding.instance.handlePointerEvent(PointerHoverEvent(
        position: customPoint, kind: PointerDeviceKind.mouse));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 92,
        position: customPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton));
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 92, position: customPoint, kind: PointerDeviceKind.mouse));
    await until(() async => (await snapshot())['volume'] == .7);
    playback.value = MusicPlaybackState.fromMap(await snapshot());
    mini.value = true;
    await command('toggle');
    await command('toggle');
    check((await snapshot())['volume'] == .7, 'Resume reverted webpage volume');
    await command('next');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    check((await snapshot())['volume'] == .7,
        'Next reverted latest webpage volume');
    await command('volume', .2);
    await controller.executeScript(
        'savedVolume = 0; player.volume = 0; document.querySelector("#volume").value = 0;');
    check((await snapshot())['volume'] == 0,
        'Webpage zero volume rejected after companion adjustment');
    await command('toggle');
    await command('toggle');
    check(
        (await snapshot())['volume'] == 0, 'Resume unmuted zero-volume choice');
    await command('volume', .3);
    await log(
        'PASS: native custom webpage click with delayed volume change, bidirectional alternation, zero volume and next/resume retention');
    final beforeSeek = await snapshot();
    await command('seek', {'seconds': 8, 'trackId': beforeSeek['trackId']});
    final afterSeek = await snapshot();
    check(((afterSeek['position'] as num) - 8).abs() < .8,
        'Native seek did not change playback position');
    await command('next');
    await controller.executeScript('''(() => {
      window.__studyMusicBridge.command('seek', {seconds: 1, trackId:${jsonEncode(beforeSeek['trackId'])}})
        .then(result => window._staleSeekResult = result.ok);
    })()''');
    await until(() async =>
        await controller.executeScript('window._staleSeekResult === false') ==
        true);
    await command('toggle');
    check((await snapshot())['playing'] == false, 'Pause failed');
    await command('toggle');
    check((await snapshot())['playing'] == true, 'Resume failed');
    await WidgetsBinding.instance.endOfFrame;
    final image = await (screen.currentContext!.findRenderObject()
            as RenderRepaintBoundary)
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${docs.path}/companion-music-controls.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    await log(
        'PASS: native local music fixture: volume UI synchronization, retained volume after track/reset, seek and stale-track rejection, next/previous, pause/resume, uninterrupted minimize');
  } finally {
    runApp(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (initialized) await controller.dispose();
    await subscription.cancel();
    mini.dispose();
    playback.dispose();
    await server.close(force: true);
  }
}

List<int> asciiEncode(String value) => value.codeUnits;
