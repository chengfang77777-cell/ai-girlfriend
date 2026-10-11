# Local webview_windows patch

Vendored runtime sources from webview_windows 0.4.0 (pub.dev), under the
upstream BSD 3-Clause license in LICENSE. The app uses this path dependency
so the fix survives dependency restoration without modifying the global cache.

- Forward wheel and trackpad positions before their scroll deltas, including
  when no hover event has arrived since opening or moving the view.
- Dispatch wheels through Chromium's input pipeline at the pointer's CSS
  coordinates, accounting for DPI and page zoom. The offscreen composition
  host silently drops SendMouseInput wheel events at positions other than
  (0, 0), reproduced by the native probe and also reported upstream:
  https://github.com/MicrosoftEdge/WebView2Feedback/discussions/4056.
  Browser hit-testing, nested scrolling, iframe routing and page wheel handlers
  remain responsible for the action; no synthetic DOM scrolling is installed.
- Explicitly allow Dart 3 in the SDK constraint used by this Flutter app.

Regression coverage: test/study_music_panel_test.dart checks channel ordering
and local coordinates; tool/windows_music_probe.dart exercises actual Windows
WebView2 scrolling inside a local nested playlist fixture.
