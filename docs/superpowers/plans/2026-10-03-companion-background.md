# Companion background implementation plan

Goal: refine all eight existing chat scenery presets with natural layered motion and smooth, inexpensive transitions.

Architecture: a standalone application-owned Canvas renderer in `assets/web/js/companion-background.js`, driven by the existing viewer frame loop. It caches base scenery and sprites; normalized particles use elapsed time. The viewer owns the public background entry point, while Flutter refreshes the new asset and displays matching preset swatches.

Tech stack: existing Canvas 2D, Three.js viewer, Flutter 3.24.5, Node tests, native Windows WebView2 probe. Execute sequentially in the current workspace; retain all existing work and do not commit.

- [x] Add failing behavior tests for preset resolution, time-based motion, transitions, resize, frame throttling, reduced motion, hidden state and study calmness.
- [x] Implement the independent renderer; integrate its frame and study hooks, refresh its asset on Windows, and update existing background swatches/descriptions.
- [x] Add and test a persisted motion preference (gentle/still/system), so the requested dynamic effect remains enabled on this machine where the OS reports reduced motion. Wire changes into the existing native viewer without reloading the model.
- [x] Run focused regressions. Use a native probe with isolated chat storage and local VRM assets to capture each preset and verify motion/transition/lifecycle behavior. Inspect the rendered images and refine if needed.
- [x] Run scoped analysis and build `lib/main.dart` Windows Release with `D:/AIcursorclaude/flutter3245` in the original output directory. Record verification evidence.

Verification evidence:
- All 44 Node behavior tests passed, including the saved first-frame theme/motion regression.
- 38 focused Flutter tests passed, covering background preferences/settings, page layout, chat focus/wheel routing, study chat/countdown and music panel.
- Scoped analysis of the six changed production Dart files and two probe/test files: no issues; the final probe adjustment was also analyzed successfully.
- Final native probe exited 0. All eight presets produced distinct animated frames, completed transitions, respected the 30 fps budget, and resized correctly. Live gentle/still/system preferences, rapid switches and study slowdown passed. The final run reported chat input focus true; inactive-window focus is additionally covered by widget tests.
- Native screenshots inspected for all eight presets and the narrow layout. A second visual pass replaced hard auroral bands with cached blurred textures and added subtle static dithering to gradients.
- Preview images and native log: `C:/Users/14966/Documents/companion-background-preview/`.
- Production build completed successfully with `--release --target=lib/main.dart` in 27.2 seconds. Output: `D:/AIcursorclaude/ai_girlfriend_vrm/build/windows/x64/runner/Release/ai_girlfriend.exe`.
