# Companion refinement implementation plan

**Goal:** Match high-five recovery to the original greeting recovery; keep study chat and countdown concurrent; unify the approved warm-white/sage/rose interface and embed NetEase's official music page if viable.

**Architecture:** The high-five layer hands its completed greeting pose back to the existing animation mixer, which uses the same idle transition as startup. Study conversation context is independent of timer state; only explicit pause/rest/end changes the countdown. One persistent avatar stays in the main stage. Chat and study share a consistent sidebar footprint, with a separate optional official music WebView in the stage.

**User-approved direction:** Warm white, sage green, a small amount of rose; retain the large character view. Improve Home, study, character list/create, settings and shared controls. User specifically chose NetEase Cloud Music after asking for an embedded player.

- [x] Add a regression for the greeting-to-idle handoff; route high-five completion into the existing mixer transition and verify actual models.
- [x] Add study regressions for chat during a running countdown, retained study system context and timer expiry while a reply is pending; fix state coupling.
- [x] Establish shared theme and refresh secondary pages, bubbles and input; preserve focus, draft and settings behavior.
- [x] Rework Home stage/sidebar layout and study visual hierarchy; keep one avatar, adaptive sizing, clear navigation and scroll behavior.
- [x] Check NetEase official endpoint metadata and add a lifecycle-safe optional WebView panel with loading/retry/close and minimize/restore. Live login/playback remains unverified; official login/catalog rules apply.
- [x] Run relevant Node/Dart tests, analyze, native interactions/visual smoke, then compile Windows Release with D:/AIcursorclaude/flutter3245 and lib/main.dart in the original output directory.

Ownership: root high-five/viewer/Home/study visuals/integration; study_panel agent study logic/prompt/tests; calm_ui agent theme/secondary pages/shared input+bubble; netease_embed agent isolated music panel. Preserve earlier uncommitted work; no commits, no TTS timeout-policy changes, no alternate build directory.

## Verification — 2026-09-30

- Node: 48 tests passed; seven actual VRM models passed gesture and recovery checks.
- Flutter: full suite of 87 tests passed, followed by all four music-panel tests passing after adding the minimize/restore regression.
- Analyzer: 10 existing warnings/infos remain in untouched platform/web files; no claim of a clean whole-project analysis.
- Native Windows probe passed high-five interactions, focus/draft retention, a persistent avatar across mode switches, study chat while the countdown continues, study system context, and one-time expiry sound/praise. Probe uses isolated storage and mocked chat responses.
- Home and study native screenshots inspected; no observed layout overflow.
- NetEase lifecycle is covered using a fake WebView platform. Browser verification of the live site was blocked by the site access policy; actual login and audio playback have not been verified.
- Final production build succeeded with `flutter build windows --release --target=lib/main.dart`, using the requested Flutter SDK and the original `build/windows/x64/runner/Release` directory.
