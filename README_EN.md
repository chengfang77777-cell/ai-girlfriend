<div align="center">

# 💗 AI Girlfriend (ai_girlfriend)

> A cross-platform AI virtual girlfriend app built with Flutter — a 3D virtual companion that talks, shows emotions, and performs actions

![Flutter](https://img.shields.io/badge/Flutter-3.2%2B-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue)
![Language](https://img.shields.io/badge/Dart-3.2%2B-0175C2)
![License](https://img.shields.io/badge/License-MIT-yellow)

**中文 README**: [README.md](./README.md)

</div>

An AI girlfriend app built with Flutter that deeply integrates **large language model conversation**, **speech synthesis**, and **3D VRM avatars**:

- Chat naturally with AI characters (powered by DeepSeek `deepseek-chat`)
- The AI **matches facial expressions and body actions in real time** based on the conversation, with **lip-sync** while speaking
- Voice playback with customizable voices (powered by Xiaomi MiMo TTS)
- Available on Windows desktop, Android phones, and Web

---

## ✨ Features

| Feature | Description |
| --- | --- |
| 💬 **AI Chat** | Powered by DeepSeek `deepseek-chat`, returns structured JSON (reply text + emotion + action), with sliding-window context, exponential-backoff retries, and timeout control |
| 😊 **Emotion System** | 6 emotions: happy / shy / angry / sad / surprised / neutral. The AI automatically detects and maps them to VRM blendshape expressions |
| 🏃 **Action Matching** | 10 built-in VRMA animations; the AI infers actions from dialogue semantics (clapping, thanking, head-shaking, greeting, yawning, getting angry, etc.), with smooth cross-fades and automatic fallback to idle |
| 👄 **Lip-Sync** | Real-time mouth driving based on AudioWorklet — the avatar's lips move in sync with the speech |
| 🔊 **Text-to-Speech (TTS)** | Xiaomi MiMo `mimo-v2.5-tts` with preset voices 「冰糖」「茉莉」and an auto-read toggle |
| 🎨 **Custom Voice** | Design your own voice by text description via `mimo-v2.5-tts-voicedesign` |
| 👧 **Preset Characters** | 7 distinct characters: Gentle Senpai, Cheerful Childhood Friend, Tsundere Deskmate, Elegant Onee-san, Healing Neighbor, Ram, Rem |
| 🧑‍🎨 **Custom Characters** | Freely create characters: set name, age, personality tags, speaking style (optional), and bind your own VRM model and voice |
| 🗨️ **WeChat Style Mimicry** | Paste a real WeChat chat log (with the other person's WeChat name and yours) when creating a character — the character will **always mimic the "other person's" tone** in conversation: catchphrases, wording habits, sentence length, emojis and punctuation, just like chatting with the real person |
| 💾 **Local Storage** | Based on Hive, persists characters, chat history (up to 5,000 messages per character) and settings — all data stays local |
| 🖼️ **Chat Backgrounds** | Multiple gradient backgrounds, each character has a default background |

---

## ⚙️ Core Implementation Details

> 3D avatar rendering, lip-sync and action switching are all implemented in `assets/web/vrm_viewer.html` (three.js + @pixiv/three-vrm, running inside a built-in WebView).

### 👄 Lip-Sync

Lip-sync directly drives the VRM Viseme expression channels (`aa / ih / oh / ou / ee`) based on **Web Audio API spectrum analysis** — no third-party lip-sync library required:

1. **Audio pipeline**: When Flutter plays TTS audio, the local shelf server hosts the audio file and sets the global `window.__pendingAudioUrl`; the page's JS polls it every 100ms and immediately creates an `<audio>` element to play.
2. **Real-time spectrum analysis**: An `AnalyserNode` (`fftSize=512`) reads frequency-domain data every **25ms** (~40fps) so the mouth stays in sync.
3. **Signal extraction**: Three metrics are computed per frame — overall RMS loudness, **spectral centroid** (timbre brightness, normalized to 250Hz–4000Hz), and band energies (low <600Hz / mid 600–2500Hz / high >2500Hz).
4. **Phoneme-driven blending (coarticulation)**: The 5 Visemes are blended continuously along the spectral centroid axis — low frequencies bias `ou`/`oh` (rounded, back vowels), mid frequencies bias `aa` (open mouth), high frequencies bias `ih`/`ee` (front, close vowels) — approximating the continuous lip motion of real speech.
5. **Perceptual loudness curve**: `pow(rms, 0.6) × 1.7` power compression keeps soft sounds softer and strong sounds more open; a silence gate of 0.018 closes the mouth quickly and naturally below it.
6. **Smoothing & naturalness**: Asymmetric smoothing with attack 0.75 (fast) / release 0.38 (slow), plus ±0.06 random jitter to avoid a robotic feel; `aa` is clamped to 0.9 and the others to ≤0.85 to prevent over-acting.

### 🎬 Smooth Action Switching System

The action system achieves "buttery" transitions using a **shared THREE.AnimationMixer + manually driven weight easing**:

1. **Shared mixer crossfade**: All VRMA clips share one `AnimationMixer`, so actions crossfade naturally without jumps.
2. **smoothstep easing**: Instead of THREE's built-in linear `crossFadeFrom` (which has velocity discontinuities at start/end), weights are driven manually each frame with a smoothstep curve `k²(3−2k)` (zero derivative at both ends), completing in 0.6s for a human-like ease-in/out.
3. **Hold-style crossfade**: The new action fades in (0→1) while the old one stays at full weight; only when the new one is ~halfway does the old fade out (1→0) — the weight sum is always ≥ 1, preventing THREE's PropertyMixer from filling the gap with the bind-pose (which caused a "tilting waist" artifact).
4. **End-frame hold + arm-track injection**: `clampWhenFinished` keeps the last frame after a clip ends; when loading a non-idle clip, the 8 arm bone tracks from the idle clip are injected automatically, so arms never snap back to the T-pose during switching — eliminating the "arms suddenly spread for a second" jump.
5. **Smart idle system**: The main `idle.vrma` loops continuously; roughly every two loops a random idle variant is inserted (yawn / happy idle / head-shake, with random jitter for naturalness) — only when no conversation or action is running, never interrupting emotional actions.
6. **Expression lerp**: Emotions are not applied instantly; they exponentially approach targets per frame (~0.5s), then the channel is released once converged (handed back to the blink/micro-expression/lip-sync systems); non-neutral expressions auto-reset to neutral after 5s to avoid a frozen face.
7. **Natural micro-details**: Double-blinks every 3–5s, plus sine-wave micro-expressions (smile/surprise/blush) while idle make the character feel alive.
8. **No T-pose flash**: On model load, the greeting clip is preloaded and its first frame applied to the bones *before* the model enters the scene; after 1000 frames of physics simulation (so hair/skirt settle), it flows straight into idle.
9. **Action semantic normalization**: The `action` field from DeepSeek is normalized against a controlled vocabulary (`talk / happy / sad / angry / refuse / thankful / clap / greeting / shake_head / yawn`); unknown values fall back to `talk` (idle + lip-sync only, no over-acting). `ACTION_MAP` maps action names to the matching VRMA file and associated expression.
10. **Seamless conversation takeover**: Sending a message does **not** stop the idle animation (so the model never freezes while the AI "thinks"); when the emotion/action clip arrives it takes over seamlessly and crossfades back to idle when finished.

### 🤖 AI Response Pipeline

```
User message
  → DeepSeek deepseek-chat (sliding 30-turn context window)
  → Parse structured JSON: { reply, emotion, action }
  → Emotion correction (e.g. if the user is sad, the AI shouldn't be happy)
  → Action inference (if the AI omits action, infer from keywords: thanks→thankful, clap→clap…)
  → Trigger TTS (MiMo) → play audio + spectrum-driven lip-sync
  → Expression exponential lerp + action smoothstep crossfade
```

### 🗨️ WeChat Style Mimicry

When creating a custom character, you can paste a real WeChat chat log and fill in the **other person's WeChat name** and **your own WeChat name**. These are persisted with the character (Hive) and injected into DeepSeek as part of the **system prompt** for every conversation:

- The system prompt explicitly instructs the AI to speak in the "other person's" tone from the log: catchphrases, wording habits, sentence length, emoji and punctuation habits — making the chat feel like messaging that real person.
- Characters without a chat log chat normally.
- The **speaking style** field is **optional**; when left blank, the AI improvises based on personality tags and the chat log.

#### 🔒 Privacy & Data Storage

Regarding the WeChat chat log, rest assured:

- **Stored locally only**: The chat log, the other person's WeChat name and your own name are saved only in the app's local Hive database (the `characters` box, located in the system's app-data directory). They are **never uploaded to any cloud or third-party storage**; they are removed when the app is uninstalled or its data is cleared.
- **Sent to DeepSeek only during conversation**: To let the AI learn the other person's tone, the chat log is included as part of the system prompt **when you chat with that character**, and sent to the official DeepSeek API (`api.deepseek.com`), which analyzes the style and returns a reply. This is the only network request required for the feature to work.
- **No other use**: The chat log is never sent to any service other than DeepSeek (MiMo TTS only receives the reply text to be read aloud, never the chat log), and is never used in any logs, statistics or feedback reporting.
- **Deletable with the character**: Deleting the character in "Character Management" also removes its chat log from the local database.

---

## 🚀 Local Setup / Deployment

### Prerequisites

| Dependency | Version | Purpose |
| --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.2.0 (Dart ≥ 3.2) | Core framework |
| [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) | with "Desktop development with C++" workload | Build Windows desktop (Windows only) |
| [Android Studio](https://developer.android.com/studio) / Android SDK | Latest stable | Build Android (optional) |

> ⚠️ **Path requirement (important)**: Please place the project under a **pure ASCII path** (no Chinese characters, spaces, or other non-ASCII characters), e.g. `D:\ai_girlfriend`. Otherwise, on Windows you will hit `ShaderCompilerException` (Flutter's impellerc shader compiler cannot write to paths containing non-ASCII characters), causing `flutter build` / `flutter run` to fail.

> 💡 **Recommended Flutter version: 3.24.5** — it delivers smoother 3D character rendering and animation on Windows in our testing. Prefer this version. After installation, add Flutter's `bin` directory to your system PATH and run the commands below from the project root:
>
> ```bash
> flutter --version      # verify it prints 3.24.5
> flutter run -d windows
> ```

> You will need two API keys before deploying:
> - **DeepSeek API Key** (chat): apply at [DeepSeek Platform](https://platform.deepseek.com/)
> - **Xiaomi MiMo API Key** (voice): apply at [MiMo API Platform](https://platform.xiaomimimo.com)

### Deployment Steps

#### 1. Clone the repository

```bash
git clone https://github.com/chengfang77777-cell/ai-girlfriend.git
cd ai-girlfriend
```

#### 2. Configure API keys (required)

`lib/core/secrets.dart` is ignored by `.gitignore` (to prevent key leakage), so you must create it from the template:

```bash
# Copy the template
copy lib\core\secrets.dart.template lib\core\secrets.dart   # Windows
# cp lib/core/secrets.dart.template lib/core/secrets.dart     # macOS / Linux

# Edit lib/core/secrets.dart and fill in your keys:
#   deepseekApiKey = "sk-xxxx"   → DeepSeek chat key
#   mimoApiKey     = "xxxx"      → Xiaomi MiMo voice key
```

> Tip: The DeepSeek key can also be entered in-app via "Settings → DeepSeek API Key"; however, the MiMo key only takes effect in `secrets.dart`, so it must be configured there.

#### 3. Install dependencies

```bash
flutter pub get
```

#### 4. Run

```bash
# Windows desktop (recommended)
flutter run -d windows

# Android (with a connected device/emulator)
flutter run -d android

# Web (experimental; subject to browser autoplay policy)
flutter run -d chrome
```

#### 5. Build release packages

```bash
flutter build windows            # Windows desktop build → build/windows/
flutter build apk --release      # Android APK → build/app/outputs/flutter-apk/app-release.apk
```

> On first build, cache directories such as `build/`, `.dart_tool/`, and `windows/flutter/ephemeral/` are automatically regenerated — no manual setup needed.

> 📱 **Ready-to-install APK**: After running `flutter build apk --release`, the artifact `build/app/outputs/flutter-apk/app-release.apk` is **an installable package that can be used directly on your phone** — just transfer this APK to your Android phone (via WeChat, cloud drive, USB, etc.) and tap to install. No Flutter environment needed.
>
> Pre-built release APKs are available on [GitHub Releases](https://github.com/chengfang77777-cell/ai-girlfriend/releases).

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) + Dart
- **State management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **Local storage**: [Hive](https://docs.hivedb.dev/) / `hive_flutter` (messages, characters, settings)
- **AI chat**: [DeepSeek](https://platform.deepseek.com/) `deepseek-chat` API
- **Speech synthesis**: [Xiaomi MiMo](https://platform.xiaomimimo.com) `mimo-v2.5-tts` / `mimo-v2.5-tts-voicedesign`
- **3D rendering**: [three.js](https://threejs.org/) + [@pixiv/three-vrm](https://github.com/pixiv/three-vrm) (runs inside a built-in WebView)
- **Local server**: [shelf](https://pub.dev/packages/shelf) (serves VRM/VRMA static assets and audio streams to the WebView)
- **WebView containers**: `webview_windows` (Windows), `webview_flutter` (Android)
- **Audio playback**: `audioplayers`; **Code generation**: `json_serializable` / `hive_generator`

### Rendering Architecture

Instead of a native 3D engine, the app loads a `three.js + three-vrm` rendering page (`assets/web/vrm_viewer.html`) into a local WebView and controls model loading, expression switching, and action playback via Dart ⇄ JavaScript communication:

```
Flutter (Dart)
   │  shelf local HTTP server
   ▼
WebView ──► three-vrm (THREE.js) ──► load VRM model / play VRMA clips / lip-sync
   ▲
   └── executeScript / webMessage: set expression, switch action, change background
```

---

## 📁 Project Structure

```
lib/
├── main.dart                       # App entry point
├── core/                           # Constants, theme, secrets, emotion mapping, backgrounds
├── data/                           # DeepSeek/TTS API wrappers, Hive storage, preset characters
├── domain/                         # Riverpod state management (character/chat/voice/background)
├── models/                         # Data models (Character / Message, Hive + JSON)
└── presentation/
    ├── pages/                      # Splash, Home, Character List, Character Create, Settings
    └── widgets/                    # Chat bubble, input bar, character card, 3D avatar widget

assets/
├── models/                         # 7 VRM 3D models (*.vrm)
├── animations/                     # 10 VRMA motion clips (*.vrma)
├── web/                            # three.js / three-vrm renderer libraries + vrm_viewer.html
└── images/                         # Character art & assets
```

---

## 📦 Bundled Assets

### VRM Models (`assets/models/`)

| Model | Character | Source |
| --- | --- | --- |
| `senpai.vrm` | Gentle Senpai | [VRoid Hub](https://hub.vroid.com/en) |
| `genki.vrm` | Cheerful Childhood Friend | [VRoid Hub](https://hub.vroid.com/en) |
| `tsundere.vrm` | Tsundere Deskmate | [VRoid Hub](https://hub.vroid.com/en) |
| `oneesan.vrm` | Elegant Onee-san | [VRoid Hub](https://hub.vroid.com/en) |
| `iyashi.vrm` | Healing Neighbor | [VRoid Hub](https://hub.vroid.com/en) |
| `ram.vrm` | Ram | [VRoid Hub](https://hub.vroid.com/en) |
| `rem.vrm` | Rem | [VRoid Hub](https://hub.vroid.com/en) |

### VRMA Animations (`assets/animations/`)

`idle.vrma` (idle), `happy idle.vrma` (happy), `sad idle.vrma` (sad), `angry.vrma` (angry), `clapping.vrma` (clap), `Thankful.vrma` (thank), `Standing Greeting.vrma` (greet), `Shaking Head No.vrma` (refuse), `Yawn.vrma` (yawn), `Head Shake idle.vrma` (head-shake idle) — all from [Mixamo](https://www.mixamo.com/).

> To swap models: put your `.vrm` file into `assets/models/`, add a `character name → filename` entry to the `_charModels` map in `lib/presentation/widgets/avatar_display.dart`, and register it under `assets` in `pubspec.yaml`.

---

## 🙏 Credits

This project stands on the shoulders of the following outstanding open-source projects and platforms. Our sincere thanks to all creators:

### Frameworks & Engines

- **[Flutter](https://flutter.dev/)** — Google's open-source cross-platform UI framework
- **[three.js](https://threejs.org/)** — The powerful Web 3D rendering engine ([MIT License](https://github.com/mrdoob/three.js/blob/dev/LICENSE))
- **[@pixiv/three-vrm](https://github.com/pixiv/three-vrm)** — VRM model rendering library by pixiv ([MIT License](https://github.com/pixiv/three-vrm/blob/main/LICENSE))
- **[Riverpod](https://riverpod.dev/)** — Reactive state management ([MIT License](https://github.com/rrousselGit/riverpod/blob/master/LICENSE))
- **[Hive](https://docs.hivedb.dev/)** — Lightweight, fast NoSQL local storage ([Apache-2.0](https://github.com/hivedb/hive/blob/main/LICENSE))
- **[shelf](https://pub.dev/packages/shelf)** — Dart lightweight HTTP server framework

### Models & Assets

- **[VRoid Hub](https://hub.vroid.com/en)** — All 7 built-in VRM character models were obtained from this platform
- **[Mixamo](https://www.mixamo.com/)** — All 10 built-in VRMA motion clips were obtained from this platform
- **[VRoid Studio](https://vroid.com/)** — The free modeling tool for creating VRM characters

### AI Services

- **[DeepSeek Platform](https://platform.deepseek.com/)** — Provides the `deepseek-chat` LLM conversation capability
- **[Xiaomi MiMo API Platform](https://platform.xiaomimimo.com)** ([MiMo Home](https://mimo.mi.com/)) — Provides `mimo-v2.5-tts` speech synthesis and voice design

### Open Source Community

Thanks to all the developers and open-source projects contributing to the Flutter ecosystem.

---

## 📄 License

This project is licensed under the [MIT License](./LICENSE).

**Note: the code and the bundled assets have different copyright holders** — the VRM models belong to their respective creators on VRoid Hub, and the VRMA animations belong to their makers; they are **not** covered by the MIT license. Please comply with each platform's terms of use (e.g., VRoid Hub's model usage terms and Adobe/Mixamo's [terms of use](https://www.adobe.com/legal/licenses-terms.html)), and verify asset licensing yourself before commercial use.

---

## 📬 Contact

- Repository: [https://github.com/chengfang77777-cell/ai-girlfriend](https://github.com/chengfang77777-cell/ai-girlfriend)
- Issues & PRs are welcome: [Issue Tracker](https://github.com/chengfang77777-cell/ai-girlfriend/issues)

If this project helps you, please give it a ⭐ Star. Thank you for your support!
