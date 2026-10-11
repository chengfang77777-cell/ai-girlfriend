# Warm interactive background implementation plan

Goal: make the eight existing animated backgrounds visibly alive, warm and responsive to the user's pointer, preserving avatar and chat controls. The user's earlier autonomous design authorization and current direction guide this iteration.

Design: deepen the layered Canvas scene with large defocused foreground lights, more readable particle motion and parallax, broader moving light ribbons, and gently breathing window light/curtains. Pointer proximity influences particles. Short primary clicks create a warm expanding bloom and floating glints; drag gestures never trigger a click bloom. Passive listeners leave orbit/high-five/chat behavior intact. Study mode suppresses click/trail effects and softens pointer influence; still mode suppresses all interaction animation. Keep the 30 fps/pixel/particle caps and bounded interaction storage.

Architecture: extend the existing `companion-background.js` renderer; retain its public theme/motion lifecycle and add bounded interaction state. Update the existing Node behavior tests and Windows native probe. No external dependencies, commits or separate build directories.

- [x] Add failing tests for bounded click effects, expiry, drag rejection, pointer hover/leave, still mode and study suppression.
- [x] Implement stronger depth/motion, cached bokeh, moving window curtains and passive interactions. Run focused Node regressions.
- [x] Extend the native probe to exercise pointer events, capture the interaction frames, and verify still/study behavior. Inspect actual Windows images and adjust visual intensity if needed.
- [x] Analyze the probe and compile production `lib/main.dart` using `D:/AIcursorclaude/flutter3245` into the original Release directory; record evidence.

Verification:
- 48 Node regressions passed, including 12 background tests for theme/motion lifecycle, interaction caps/expiry, passive listeners, drag/long-press/non-primary rejection, hover fade, study and still modes.
- 20 focused Flutter tests passed for background preferences/settings, page layout, persistent chat input focus and wheel routing.
- Scoped analysis of the changed settings page and native probe: no issues.
- Final native Windows probe exited 0. All eight themes animated within the frame budget, transitioned and resized. Actual Flutter mouse input reached WebView2 and produced hover light and a tap bloom. Drag rejection, leave/expiry, study suppression and static canvas checks passed. Inactive native-window keyboard focus is covered by widget regressions.
- Inspected all eight scene screenshots and the warm interaction frame. Refined hollow bokeh rings into filled feathered lens disks. Previews/log: `C:/Users/14966/Documents/companion-background-preview/`.
- Final production build succeeded with `--release --target=lib/main.dart` in 24.2 seconds, using the requested Flutter SDK. Output remains `D:/AIcursorclaude/ai_girlfriend_vrm/build/windows/x64/runner/Release/ai_girlfriend.exe`.
