# Greeting-based high five and study companion implementation plan

**Goal:** Reuse the original greeting animation for the complete high five, and ship the approved emotional study companion with configurable countdown and completion sound/action/praise.

**Architecture:** The viewer owns greeting playback, pause/resume, palm hit testing, quiet study idle and a local completion chime. A Dart countdown controller owns wall-clock state and restoration. A StudyPanel overlays the existing HomePage avatar so there is only one WebView, with separate companion conversation and local study progress.

**Tech stack:** Flutter 3.24.5, Riverpod, Hive settings, Three.js/VRMA, existing chat/TTS providers. Original Windows Release directory only.

- [x] Inspect greeting clip and choose the first raised-hand frame and original lowering segment; replace procedural arm solving with actual clip sampling, freeze/resume and cancellation tests.
- [x] Implement and test StudySessionController: configurable duration, pause/support/rest/resume, exactly-once expiry, restart as paused, local JSON persistence.
- [x] Add optional study system context to existing chat API and test isolation; companionship prompt uses actual goal/time/context, no tutoring, guilt or repeated slogans.
- [x] Implement StudyPanel with duration/goal inputs, countdown, supportive conversation, rest/resume/end, local state and user-controlled record removal. Completion produces immediate local praise plus callback for sound/happy action/voice.
- [x] Wire HomePage to StudyPanel, retain the same avatar, stop unrelated speech on mode transitions; implement viewer quiet mode and completion chime/action bridges.
- [x] Run Node/Dart regression, real greeting-frame and multi-model checks, native timer/bridge smoke where feasible, and build production Windows target in the original directory.

Parallel ownership: root owns viewer/high-five.js/AvatarDisplay/HomePage integration; domain agent owns study_session.dart, study_companion.dart, optional API context and their tests; UI agent owns StudyPanel and its tests. No TTS timeout-policy changes.

Verification completed (2026-09-29):
- 47 Node tests passed; Flutter full suite passed 71 tests, then all 22 study tests passed including the new deadline-pause regression (72 total tests now).
- Seven real VRMs passed canvas palm/miss/drag/hit/return checks, cancellation and chat interruption; no page errors.
- Compared all 53 greeting tracks across the full raise/return range on all seven models; maximum quaternion numerical error <0.002 radians, position error <1e-6.
- Native Windows probe passed mouse/bridge/focus checks and study timer: same avatar retained, restored paused, quiet focus, two local notes, immediate offline praise once, no replay on reopen.
- Scoped analyzer clean; production build succeeded using Flutter D:/AIcursorclaude/flutter3245, --release --target=lib/main.dart in original build/windows/x64/runner/Release.
- Online TTS/LLM quality was not evaluated with paid requests; existing timeout policy is unchanged.
