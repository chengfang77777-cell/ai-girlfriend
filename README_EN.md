<div align="center">

# 💗 AI Girlfriend (ai_girlfriend)

> A cross-platform AI virtual girlfriend app built with Flutter — a 3D virtual companion that talks, shows emotions, and performs actions

![Flutter](https://img.shields.io/badge/Flutter-3.2%2B-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue)
![Language](https://img.shields.io/badge/Dart-3.2%2B-0175C2)
![License](https://img.shields.io/badge/License-Unspecified-lightgrey)

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
| 🧑‍🎨 **Custom Characters** | Freely create characters: set name, age, personality tags, speaking style, and bind your own VRM model and voice |
| 💾 **Local Storage** | Based on Hive, persists characters, chat history (up to 5,000 messages per character) and settings — all data stays local |
| 🖼️ **Chat Backgrounds** | Multiple gradient backgrounds, each character has a default background |

---

## 🚀 Local Setup / Deployment

### Prerequisites

| Dependency | Version | Purpose |
| --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.2.0 (Dart ≥ 3.2) | Core framework |
| [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) | with "Desktop development with C++" workload | Build Windows desktop (Windows only) |
| [Android Studio](https://developer.android.com/studio) / Android SDK | Latest stable | Build Android (optional) |

> You will need two API keys before deploying:
> - **DeepSeek API Key** (chat): apply at [DeepSeek Platform](https://platform.deepseek.com/)
> - **Xiaomi MiMo API Key** (voice): apply at [MiMo API Platform](https://platform.xiaomimimo.com)

### Deployment Steps

#### 1. Clone the repository

```bash
git clone https://gitee.com/chengfang77777/aigirlfriend.git
cd aigirlfriend
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

The current repository does not declare an open-source license. **All assets remain the property of their respective authors**: VRM models belong to their creators on VRoid Hub, and VRMA animations belong to their makers. Please comply with each platform's terms of use (e.g., VRoid Hub's model usage terms and Adobe/Mixamo's [terms of use](https://www.adobe.com/legal/licenses-terms.html)).

---

## 📬 Contact

- Repository: [https://gitee.com/chengfang77777/aigirlfriend](https://gitee.com/chengfang77777/aigirlfriend)
- Issues & PRs are welcome: [Issue Tracker](https://gitee.com/chengfang77777/aigirlfriend/issues)

If this project helps you, please give it a ⭐ Star. Thank you for your support!
