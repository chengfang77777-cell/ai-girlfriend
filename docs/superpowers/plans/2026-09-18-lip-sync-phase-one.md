# Lip sync phase one implementation plan

**Goal:** Improve the existing audio-driven mouth animation and deliver a Windows Release build using `D:\AIcursorclaude\flutter3245`.

**Architecture:** Keep the existing five-vowel frequency heuristic, but compute loudness from waveform RMS and drive deterministic, bounded mouth weights with elapsed-time smoothing. Run updates after the animation mixer and before VRM update. Ship the local JavaScript module with the viewer and overwrite its cached copy on startup.

**Scope:** Phase one approved in the conversation. No phoneme service, new model dependency, or other platform builds.

- [x] Add Node regression tests for silence, deterministic output, gate hysteresis, amplitude response, frame-rate independence, bounded combinations, and audio cleanup.
- [x] Implement `assets/web/js/lip-sync.js` with centralized tuning parameters, waveform RMS, linear-amplitude spectral features, hysteresis, and separate amplitude/shape smoothing.
- [x] Update `assets/web/vrm_viewer.html` to reuse analysis buffers, remove random mouth jitter and interval-driven mouth updates, and clean up playback failures and interruptions.
- [x] Update `lib/presentation/widgets/avatar_display.dart` to refresh the application-owned lip sync script in the local viewer directory on every initialization.
- [x] Run `node --test test/lip_sync_test.cjs`, Flutter tests, and the Windows Release build. Verify the built assets match the sources and document the executable path and tuning parameters.

## Validation

Synthetic PCM/spectrum fixtures exercise the signal-processing behavior without TTS calls. Playback lifecycle tests use a simulated media element and audio graph to exercise the actual viewer controller. Build with `& 'D:\AIcursorclaude\flutter3245\bin\flutter.bat' build windows --release`. Human visual evaluation remains necessary for each character and voice.

## Result

- 14 Node lip-sync tests passed.
- 4 Flutter tests passed after repairing the existing startup test fixture (temporary Hive storage and ProviderScope).
- Windows Release build succeeded with Flutter 3.24.5 from the requested SDK path.
- SHA-256 comparisons verified both shipped viewer assets match the source files.
- Visual character/voice tuning remains a user playback evaluation; no TTS requests were made during automated tests.
