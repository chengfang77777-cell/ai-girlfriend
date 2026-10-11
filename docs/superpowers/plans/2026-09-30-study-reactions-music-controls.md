# Study reactions and compact music controls

## Follow-up: embedded music wheel input (2026-10-03)

- Reproduced the failure in a local native WebView2 playlist: upstream wheel
  input always arrived at (0, 0), missing the nested scroll area. Merely passing
  the current pointer position made SendMouseInput return S_OK while dropping
  every non-origin wheel, consistent with WebView2Feedback discussion 4056.
- Vendored webview_windows 0.4.0 runtime sources and BSD license as a local path
  dependency. Wheel and trackpad input now update the pointer position before
  scrolling; native scrolling uses Input.dispatchMouseEvent with CSS coordinates
  and deltas corrected for DPI and page zoom. The browser retains hit-testing,
  trusted wheel events and preventDefault behavior. No global cache patch.
- Native local probe passed vertical and horizontal nested scrolling without a
  preceding hover, an offset panel at 150% DPI with 80% page zoom, iframe scrolling
  and page wheel cancellation. Existing native volume, progress, track controls
  and uninterrupted minimization also passed.
- Focused Flutter suite: 13 passed (including trackpad, chat wheel and Ctrl zoom).
  Music bridge and viewer wheel Node tests: 13 passed. Scoped Dart analysis clean.
- Final production `lib/main.dart` Windows Release build succeeded using
  `D:/AIcursorclaude/flutter3245` in the original `build/windows/x64/runner/Release`
  directory. Only the six documented local plugin files differ from upstream.
- Live NetEase verification remains unavailable under the site-access restriction;
  all native tests used the local fixture.

## Previous scope and verification

User scope: preserve the requested study conversation actions without pausing the clock; show the current song and previous/next/volume controls in the lower-left minimized NetEase panel. Retain the approved warm-white/sage UI.

- [x] Preserve the API action in StudyPanel history and reply delivery; pass it to the same avatar action entry point as regular chat. Keep quiet idle and timer state unchanged. Verify both delivered action and the next request's history.
- [x] Add an isolated music bridge asset installed before page scripts: observe standard MediaSession metadata/actions and HTML media (including detached audio), with semantic page-button fallback. Commands operate only on the embedded official music document; expose actual availability and failures, never fabricate titles or successful commands.
- [x] Display title/artist, previous/play-pause/next and a volume slider in a 360px compact lower-left card. Preserve the native controller while minimized. Clear stale state on navigation, bound command waits, and retain retry/expand/close access.
- [x] Test bridge behavior with local media fixtures, test native-to-Flutter state/command routing and lifecycle/compact layout, run study regressions and scoped analysis, then build Windows in the original Release directory with the specified Flutter SDK.

Live NetEase navigation was blocked by site-access policy in the preceding task; do not work around that restriction. Native bridge verification uses a local fixture, and final delivery must distinguish it from live NetEase compatibility.

Verification (2026-09-30):
- Red/green study regression reproduced `thankful` becoming `talk`, then confirmed action delivery and history preservation while focusing.
- Full Flutter suite: 92 passed. Added the lost-acknowledgement timeout regression afterward; all 6 panel tests passed, including after final state-error guards.
- Node suite: 53 passed, including media metadata, detached audio, capability gating, handler errors, semantic controls and same-origin frames.
- Scoped analyzer: no issues in the 10 changed production/test/probe files.
- Native avatar probe confirmed `thankful` + `happy` reached the viewer during an active countdown; existing high-five and study completion checks also passed.
- Native local WebView2 music probe passed metadata, actual audio start, next/previous, volume, pause/resume and uninterrupted minimization. Probe-only pointer positioning and single-subscription test-harness errors were corrected before the successful standalone music run.
- Inspected `C:/Users/14966/Documents/companion-music-controls.png`; compact card has no overflow.
- Final production `lib/main.dart` Windows Release build succeeded with the requested SDK in the original output folder at 15:14. No live NetEase playback compatibility claim.

## Follow-up: retained volume and seek bar

Latest user request retains the volume slider and adds a separate progress slider below it, superseding the earlier request to replace volume.

- Removed snapshot-driven overwriting of the user's chosen volume. Managed audio elements retain the chosen level across both reused-element and replacement-element track resets. Explicit labeled webpage volume input is allowed to update the preference; an available standard page range input receives normal input/change events so its own state can save the new level.
- Added finite duration/current position, seek capability and track identity to bridge snapshots. Seeking is bounded to available ranges, uses a registered media seek handler when available, and rejects a stale track identity.
- Compact card now has separate volume and progress controls with current/total time. A track switch during a drag cancels the pending seek. Unsupported/unknown-duration media keeps seek disabled.
- Verification: 8 bridge tests and 9 music widget/panel tests passed; scoped analysis clean. Native local WebView2 fixture verified volume UI synchronization, volume retention after next-track and late reset, actual seeking, stale-track rejection, and existing playback controls. Updated compact-card screenshot inspected with no overflow.
- Actual NetEase online DOM/playback remains unverified; the native verification uses an owned local page and does not bypass the previously reported site-access restriction.

## Correction: webpage volume must remain authoritative

The previous volume setter substituted a remembered value unless a labeled slider had produced a trusted event within 750 ms. This blocked custom controls and delayed handlers. The setter now forwards the exact requested value and only observes successful writes. Same-track webpage changes become the latest preference immediately; pause/resume does not restore an older value. The preference is restored once when initializing a different track, using the page's standard range input where available. Subsequent webpage writes are accepted rather than classified as unwanted resets.

Regression evidence: three formerly failing cases now pass (unlabeled webpage writes, delayed/custom changes, alternating controls and zero volume); all 9 bridge tests and 9 music widget/panel tests pass. The panel test confirms polling updates the displayed volume without sending a write-back command. A native WebView2 fixture verifies an actual click on an unlabeled custom button whose handler updates volume after one second, both control directions, zero volume, next-track and pause/resume retention. Native seek/track-safety checks continue to pass. These results validate the local reproduction, not the live NetEase website.
