<div align="center">

# 💗 AI 女友 (ai_girlfriend)

> 基于 Flutter 的跨平台 AI 虚拟女友应用 —— 会说话、有表情、能做动作的 3D 虚拟伴侣

![Flutter](https://img.shields.io/badge/Flutter-3.2%2B-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue)
![Language](https://img.shields.io/badge/Dart-3.2%2B-0175C2)
![License](https://img.shields.io/badge/License-MIT-yellow)

**English README**: [README_EN.md](./README_EN.md)

</div>

一个用 Flutter 开发的 AI 女友应用，将 **大语言模型对话**、**语音合成** 与 **3D VRM 虚拟形象** 深度融合：

- 自由选择与切换对话大模型（**DeepSeek** `deepseek-chat` 或 **小米 MiMo** `mimo-v2.5` / `mimo-v2.5-pro`）
- AI 会根据对话内容**实时匹配情绪表情与身体动作**，说话时**口型同步**
- 支持语音朗读与自定义音色（基于小米 MiMo TTS）
- **沉浸式伴读陪伴**：学习番茄钟、自习静音专注模式、专属庆祝动作与伴读音乐/白噪音
- **趣味肢体交互**：击掌互动（High-Five）、抬手呼应与即时情绪反馈
- **动态粒子伴读背景**：8 套沉浸式动态粒子背景（落樱、星空、萤火、飘雪等），支持动态幅度调节
- 覆盖 **Windows 桌面端** 与 **Android 手机端**（两端全功能深度对齐），提供即装即用的 Release 安装包

---

## ✨ 功能特性

| 功能 | 说明 |
| --- | --- |
| 💬 **AI 对话双引擎** | 支持 **DeepSeek**（`deepseek-chat`）与 **小米 MiMo**（`mimo-v2.5` / `mimo-v2.5-pro`）自由切换，统一结构化 JSON（回复文本 + 情绪 + 动作），滑动窗口上下文与自动重试 |
| 📖 **专注伴读模式** | 番茄钟自习陪伴与阶段专注计时，开启后角色进入静音专注状态（仅保留自然呼吸与微表情，无无关动作干扰），完成目标触发专属庆祝动效与音效 |
| 🎵 **伴读音乐与白噪音** | 内置专注轻音乐与白噪音控制面板，可随时启闭并独立调节音量，学习工作更沉浸 |
| ✋ **击掌互动 (High-Five)** | 随时发起与女友击掌，角色抬手响应、等待击掌、命中庆祝，全程防连击且自动恢复待机（Windows 与 Android 双端完全对齐） |
| 🌌 **动态伴读背景** | 8 套沉浸式动态主题（梦幻星空、落樱纷飞、温馨小窝、渐变柔光、清新草甸、日落黄昏、冰雪世界、神秘夜幕），带实时粒子渲染与 3 级动态幅度调节（微动/生动/静止） |
| 😊 **情绪系统** | 8 种情绪（开心 / 害羞 / 生气 / 难过 / 惊讶 / 平静 / 拒绝 / 感谢），AI 自动识别并平滑过渡到 VRM Blendshape 表情 |
| 🏃 **动作匹配** | 内置 10 个 VRMA 动画，依据语义推断动作，基于 smoothstep 曲线平滑交叉淡入，并自动回落到待机 |
| 👄 **口型同步** | 基于 AudioWorklet / Web Audio API 的频谱分析实时驱动 Viseme 通道，播放语音嘴唇同步开合 |
| 🔊 **语音合成 (TTS)** | 小米 MiMo `mimo-v2.5-tts`，预设「冰糖」「茉莉」等音色，支持自动朗读开关 |
| 🎨 **自定义音色** | 通过 `mimo-v2.5-tts-voicedesign` 用文字描述设计专属声线 |
| 👧 **预设角色** | 7 个性格迥异的角色：温柔学姐、活泼青梅、傲娇同桌、知性御姐、治愈邻家、拉姆、蕾姆 |
| 🧑‍🎨 **自定义角色** | 自由创建角色：姓名、性格、说话风格，绑定专属 VRM 模型与声线 |
| 🗨️ **微信风格模仿** | 上传真实微信聊天记录，角色在对话中模仿「对方」的用词、语气、标点与表情习惯 |
| 🧹 **聊天记录管理** | 支持单角色聊天一键清空（聊天页快捷按钮/卡片菜单）与全局记录一键清空（设置页二次确认） |
| 🔑 **纯界面密钥配置** | DeepSeek 与 MiMo 密钥 100% 支持在设置页图形化配置并存入本地 Hive，源码零明文泄露 |
| 💾 **本地存储** | 基于 Hive 本地加密存储角色、消息与设置，无任何云端数据库依赖，保护隐私 |

---

## ⚙️ 核心实现原理

> 3D 形象渲染、口型同步与动作切换全部实现在 `assets/web/vrm_viewer.html`（three.js + @pixiv/three-vrm，运行于内置 WebView 中）。

### 👄 口型同步（Lip-Sync）

基于 **Web Audio API 频谱分析** 直接驱动 VRM 的 Viseme 表情通道（`aa / ih / oh / ou / ee`），不依赖任何第三方口型库：

1. **音频链路**：Flutter 播放 TTS 音频时，通过本地 shelf 服务器托管音频文件并设置全局变量 `window.__pendingAudioUrl`；页面 JS 每 100ms 轮询该变量，发现后立即创建 `<audio>` 元素播放。
2. **实时频谱分析**：使用 `AnalyserNode`（`fftSize=512`）每 **25ms**（约 40fps）读取一次频域数据，保证口型跟手。
3. **信号提取**：从频谱实时计算三项指标 —— 总响度 RMS、**频谱质心**（音色明暗，归一化到 250Hz~4000Hz）、分频段能量（低 <600Hz / 中 600~2500Hz / 高 >2500Hz）。
4. **音素驱动（协同发音）**：以频谱质心为轴对 5 个 Viseme 做连续混合 —— 低频偏向 `ou`/`oh`（圆唇、后元音），中频偏向 `aa`（张大嘴），高频偏向 `ih`/`ee`（前、闭元音），近似真人发音时嘴唇的连续变化。
5. **感知响度曲线**：`pow(rms, 0.6) × 1.7` 幂压缩，弱音更柔、强音更张；静音门限 0.018，低于门限嘴唇快速自然闭合。
6. **平滑与自然化**：攻击系数 0.75（快）/ 释放系数 0.38（慢）的不对称平滑，叠加 ±0.06 随机抖动避免机械感；`aa` 幅度上限 0.9、其余 ≤0.85，防止"张不开嘴"或"过犹不及"。

### 🎬 动作切换流畅系统

动作系统基于 **统一的 THREE.AnimationMixer + 手动权重缓动** 实现"丝滑"的动作衔接：

1. **统一 Mixer 交叉淡入**：所有 VRMA 动作共用一个 `AnimationMixer`，动作之间可以自然交叉淡入淡出，无跳变。
2. **smoothstep 缓动**：不采用 THREE 内置的线性 `crossFadeFrom`（起止瞬间速度突变），而是每帧手动驱动动作权重，以 smoothstep 曲线 `k²(3−2k)`（两端导数为 0）过渡，0.6s 完成，如真人般渐入渐出。
3. **保持式交叉淡入（Hold-style Crossfade）**：新动作先渐入（0→1），原动作保持满权重，等新动作起来约一半再渐出（1→0）——全程权重和 ≥ 1，避免 THREE PropertyMixer 用绑定旧姿势补齐差额导致"歪腰"。
4. **末帧保持 + 手臂轨道注入**：`clampWhenFinished` 让动作播完"保持"最后一帧；加载非待机动作时自动注入待机动画的 8 条手臂骨骼轨道（肩膀→手指），切换瞬间手臂权重不会归零回落成 T-pose，彻底消除"双手突然张开一秒"的跳变。
5. **智能待机系统**：主待机 `idle.vrma` 循环播放，每播约两次后随机插入一个变体待机（打哈欠 / 开心 / 摇头，带随机抖动更自然）；仅在无对话、无动作时插入，绝不打断情绪动作。
6. **表情平滑插值**：情绪表情不瞬时切换，而是逐帧指数趋近目标值（约 0.5s 完成），收敛后自动释放该通道（交还给眨眼/微表情/口型系统）；情绪表情展示 5 秒后自动恢复中立，避免表情定格不动。
7. **自然微细节**：每 3~5 秒的双眨眼、待机时的正弦波微笑 / 惊讶 / 脸红微表情，让角色"活"起来。
8. **避免 T-pose 闪现**：加载模型时先预加载问候动作并把其首帧应用到骨骼，模型才进入场景；再经 1000 帧物理模拟让头发/裙子充分稳定，问候结束直接进入待机。
9. **动作语义收敛**：DeepSeek 返回的 `action` 字段被收敛到受控词表（`talk / happy / sad / angry / refuse / thankful / clap / greeting / shake_head / yawn`），未知值回退为 `talk`（仅保持待机与口型，不过度"表演"）；由 `ACTION_MAP` 将动作名映射到对应 VRMA 文件与关联表情。
10. **对话无缝接管**：用户发送消息时**不停止**待机动画（避免 AI 思考期间模型定格），情绪/动作动画到达时无缝接管，播完再平滑交叉淡入回待机。

### 🤖 AI 响应处理流程

```
用户消息
  → DeepSeek deepseek-chat（滑动窗口 30 轮上下文）
  → 解析结构化 JSON：{ reply 回复文本, emotion 情绪, action 动作 }
  → 情绪修正（根据用户语义：说难过时 AI 不该开心）
  → 动作推断（AI 漏给 action 时按关键词语义推断：感谢→thankful、鼓掌→clap…）
  → 触发 TTS 语音合成（MiMo）→ 播放音频 + 频谱驱动口型
  → 表情指数插值过渡 + 动作 smoothstep 交叉淡入播放
```

### 🗨️ 微信聊天风格模仿

创建自定义角色时，可粘贴一段你与某人的真实微信聊天记录，并填写**对方微信名**与**你自己的微信名**。这些信息会随角色一起持久化保存（Hive），并在每次对话时作为 **system prompt** 注入 DeepSeek：

- 系统提示词会明确要求 AI 以聊天记录中「对方」的口吻发言：口头禅、用词习惯、句子长短、表情符号、标点习惯等，让对话体验接近"和那个人本人在微信聊天"
- 未上传聊天记录的角色按普通方式聊天
- 「说话风格」字段为**可选**，留空时 AI 会根据性格标签与聊天记录自然发挥

#### 🔒 隐私与数据存储

关于微信聊天记录，请放心以下几点：

- **只保存在本地**：聊天记录、对方微信名、你的微信名仅存入应用本地 Hive 数据库（`characters` box，位于系统应用数据目录），**不会上传到任何云端、不会发送到任何第三方存储服务**，删除应用或清除数据后即被清除。
- **仅在对话时发送给 DeepSeek**：为了让 AI 学会对方的语气，聊天记录会作为系统提示词的一部分，在**该角色发起对话时**发送给 DeepSeek 官方 API（`api.deepseek.com`），由 DeepSeek 解析人物语气后返回回复。这是该功能得以实现所必需的唯一网络请求。
- **不用于其他用途**：聊天记录不会被发送给除 DeepSeek 以外的任何服务（如 MiMo TTS 仅收到待朗读的回复文本，不含聊天记录），也不会被用于应用内任何日志、统计或反馈上报。
- **随角色可删除**：在「角色管理」中删除该角色时，其聊天记录会随角色数据一并从本地数据库删除。

---

## 🚀 本地部署

### 环境要求

| 依赖 | 版本 | 用途 |
| --- | --- | --- |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.2.0（Dart ≥ 3.2） | 核心框架 |
| [Visual Studio 2022](https://visualstudio.microsoft.com/zh-hans/downloads/) | 勾选「使用 C++ 的桌面开发」 | 构建 Windows 桌面版（仅 Windows 需要） |
| [Android Studio](https://developer.android.com/studio) / Android SDK | 最新稳定版 | 构建 Android 版（可选） |

> ⚠️ **路径要求（重要）**：请将项目放在**纯英文路径**下（不要包含中文、空格等非 ASCII 字符），例如 `D:\ai_girlfriend`。否则在 Windows 上编译时会遇到 `ShaderCompilerException`（Flutter 的 impellerc 着色器编译器无法写入含非 ASCII 字符的路径），导致 `flutter build` / `flutter run` 失败。

> 💡 **推荐 Flutter 版本：3.24.5**。实测该版本在 Windows 上 3D 角色渲染与动画表现更流畅，建议优先安装使用。安装完成后将 Flutter 的 `bin` 目录加入系统 PATH，即可在项目目录下直接执行：
>
> ```bash
> flutter --version      # 验证版本号应为 3.24.5
> flutter run -d windows
> ```

> 部署前需准备两个 API Key：
> - **DeepSeek API Key**（对话）：在 [DeepSeek 开放平台](https://platform.deepseek.com/) 申请
> - **小米 MiMo API Key**（语音）：在 [MiMo API 开放平台](https://platform.xiaomimimo.com) 申请

### 部署步骤

#### 1. 克隆仓库

```bash
git clone https://github.com/chengfang77777-cell/ai-girlfriend.git
cd ai-girlfriend
```

#### 2. 配置 API 密钥（必须）

仓库中的 `lib/core/secrets.dart` 已被 `.gitignore` 忽略（防止密钥泄露），需从模板复制并填写：

```bash
# 复制模板
copy lib\core\secrets.dart.template lib\core\secrets.dart   # Windows
# cp lib/core/secrets.dart.template lib/core/secrets.dart     # macOS / Linux

# 编辑 lib/core/secrets.dart，填入你的密钥：
#   deepseekApiKey = "sk-xxxx"   → DeepSeek 对话密钥
#   mimoApiKey     = "xxxx"      → 小米 MiMo 语音密钥
```

> 提示：DeepSeek Key 也可以在应用内「设置 → DeepSeek API Key」中填写；但 MiMo 密钥仅在 `secrets.dart` 中生效，必须在此配置。

#### 3. 安装依赖

```bash
flutter pub get
```

#### 4. 运行

```bash
# Windows 桌面版（推荐）
flutter run -d windows

# Android（需连接设备/模拟器）
flutter run -d android

# Web 端（实验性，受浏览器自动播放策略限制）
flutter run -d chrome
```

#### 5. 构建发布包

```bash
# Windows 桌面版 Release
flutter build windows --release
# 生成 Windows 绿色可执行目录：build/windows/x64/runner/Release/ai_girlfriend.exe

# Android 手机版分架构 Release（推荐，包体小适配好）
flutter build apk --release --split-per-abi
# 生成 3 个架构分包：
# 1. build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (约 131MB，主流手机首选)
# 2. build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (约 128MB，老旧32位手机)
# 3. build/app/outputs/flutter-apk/app-x86_64-release.apk      (约 132MB，模拟器/平板)
```

> 📱 **可直接安装的手机 APK**：日常使用推荐将 `app-arm64-v8a-release.apk` 发送至 Android 手机（微信文件传输、QQ、USB 数据线或网盘），点击即可直接安装使用，无需配置任何开发环境。
>
> 📦 **二进制发布包规范**：
> 编译产物（`.apk` 与 `.exe`）体积较大（包含 3D VRM 模型与 Web 渲染资源），已被 `.gitignore` 排除，**不会提交至 Git 代码仓库**（防止代码库膨胀及触发 Gitee 100MB 单文件限制）。所有编译好的成品一律通过 [GitHub Releases](https://github.com/chengfang77777-cell/ai-girlfriend/releases) 发布与分发。

---

## 🛠️ 技术栈

- **框架**：[Flutter](https://flutter.dev/) + Dart
- **状态管理**：[Riverpod](https://riverpod.dev/)（flutter_riverpod）
- **本地存储**：[Hive](https://docs.hivedb.dev/) / hive_flutter（消息、角色、设置）
- **AI 对话**：[DeepSeek](https://platform.deepseek.com/) `deepseek-chat` API
- **语音合成**：[小米 MiMo](https://platform.xiaomimimo.com) `mimo-v2.5-tts` / `mimo-v2.5-tts-voicedesign`
- **3D 渲染**：[three.js](https://threejs.org/) + [@pixiv/three-vrm](https://github.com/pixiv/three-vrm)（运行于内置 WebView）
- **本地服务器**：[shelf](https://pub.dev/packages/shelf)（WebView 内提供 VRM/VRMA 静态资源与音频流）
- **WebView 容器**：`webview_windows`（Windows）、`webview_flutter`（Android）
- **音频播放**：`audioplayers`；**代码生成**：`json_serializable` / `hive_generator`

### 渲染架构

应用不依赖原生 3D 引擎，而是：将 `three.js + three-vrm` 前端渲染页面（`assets/web/vrm_viewer.html`）加载进本地 WebView，并通过 Dart ⇄ JavaScript 双向通信控制模型加载、表情切换与动作播放：

```
Flutter (Dart)
   │  shelf 本地 HTTP 服务
   ▼
WebView ──► three-vrm (THREE.js) ──► 加载 VRM 模型 / 播放 VRMA 动画 / 口型同步
   ▲
   └── executeScript / webMessage：设置表情、切换动作、更换背景
```

---

## 📁 项目结构

```
lib/
├── main.dart                       # 应用入口
├── core/                           # 常量、主题、密钥、情绪映射、背景配置
├── data/                           # DeepSeek/TTS API 封装、Hive 存储、预设角色
├── domain/                         # Riverpod 状态管理（角色/聊天/语音/背景）
├── models/                         # 数据模型（Character / Message，Hive + JSON）
└── presentation/
    ├── pages/                      # 启动页、主页、角色列表、角色创建、设置
    └── widgets/                    # 聊天气泡、输入栏、角色卡片、3D 形象组件

assets/
├── models/                         # 7 个 VRM 3D 模型（*.vrm）
├── animations/                     # 10 个 VRMA 动作动画（*.vrma）
├── web/                            # three.js / three-vrm 渲染库 + vrm_viewer.html
└── images/                         # 角色立绘与素材
```

---

## 📦 内置资源

### VRM 模型（`assets/models/`）

| 模型 | 角色 | 来源 |
| --- | --- | --- |
| `senpai.vrm` | 温柔学姐 | [VRoid Hub](https://hub.vroid.com/en) |
| `genki.vrm` | 活泼青梅 | [VRoid Hub](https://hub.vroid.com/en) |
| `tsundere.vrm` | 傲娇同桌 | [VRoid Hub](https://hub.vroid.com/en) |
| `oneesan.vrm` | 知性御姐 | [VRoid Hub](https://hub.vroid.com/en) |
| `iyashi.vrm` | 治愈邻家 | [VRoid Hub](https://hub.vroid.com/en) |
| `ram.vrm` | 拉姆 | [VRoid Hub](https://hub.vroid.com/en) |
| `rem.vrm` | 蕾姆 | [VRoid Hub](https://hub.vroid.com/en) |

### VRMA 动作（`assets/animations/`）

`idle.vrma`（待机）、`happy idle.vrma`（开心）、`sad idle.vrma`（难过）、`angry.vrma`（生气）、`clapping.vrma`（鼓掌）、`Thankful.vrma`（道谢）、`Standing Greeting.vrma`（打招呼）、`Shaking Head No.vrma`（摇头拒绝）、`Yawn.vrma`（打哈欠）、`Head Shake idle.vrma`（摇头待机）——均来自 [Mixamo](https://www.mixamo.com/)。

> 如需更换模型：将 `.vrm` 文件放入 `assets/models/`，并在 `lib/presentation/widgets/avatar_display.dart` 的 `_charModels` 映射中添加角色名 → 文件名，同时在 `pubspec.yaml` 的 assets 中登记。

---

## 🙏 致谢 (Credits)

本项目站在以下优秀开源项目与平台之上，衷心感谢所有创作者：

### 框架与引擎

- **[Flutter](https://flutter.dev/)** — Google 开源的跨平台 UI 框架
- **[three.js](https://threejs.org/)** — 强大的 Web 3D 渲染引擎（[MIT License](https://github.com/mrdoob/three.js/blob/dev/LICENSE)）
- **[@pixiv/three-vrm](https://github.com/pixiv/three-vrm)** — pixiv 出品的 VRM 模型渲染库（[MIT License](https://github.com/pixiv/three-vrm/blob/main/LICENSE)）
- **[Riverpod](https://riverpod.dev/)** — 响应式状态管理（[MIT License](https://github.com/rrousselGit/riverpod/blob/master/LICENSE)）
- **[Hive](https://docs.hivedb.dev/)** — 轻量高效的 NoSQL 本地存储（[Apache-2.0](https://github.com/hivedb/hive/blob/main/LICENSE)）
- **[shelf](https://pub.dev/packages/shelf)** — Dart 轻量 HTTP 服务器框架

### 模型与素材

- **[VRoid Hub](https://hub.vroid.com/en)** — 本应用内置的全部 7 个 VRM 3D 角色模型均取自该平台
- **[Mixamo](https://www.mixamo.com/)** — 本应用内置的全部 10 个 VRMA 动作动画均取自该平台
- **VRoid Studio**（[官网](https://vroid.com/)）— 创作 VRM 角色的免费建模工具

### AI 服务

- **[DeepSeek 开放平台](https://platform.deepseek.com/)** — 提供 `deepseek-chat` 大模型对话能力
- **[小米 MiMo API 开放平台](https://platform.xiaomimimo.com)**（[MiMo Home](https://mimo.mi.com/)）— 提供 `mimo-v2.5-tts` 语音合成与音色设计能力

### 开源社区

感谢所有为 Flutter 生态贡献的开发者与开源项目。

---

## 📄 许可证

本项目采用 [MIT License](./LICENSE)。

**注意：代码与内置素材的版权归属不同** —— VRM 模型版权归 VRoid Hub 上的各模型作者，VRMA 动画版权归其制作者，它们**不在 MIT 许可范围内**。请遵守各来源平台的用户协议（如 VRoid Hub 的模型使用条款、Mixamo 的 [用户协议](https://www.adobe.com/legal/licenses-terms.html)），商用前请自行确认素材授权。

---

## 📬 联系方式

- 项目仓库：[https://github.com/chengfang77777-cell/ai-girlfriend](https://github.com/chengfang77777-cell/ai-girlfriend)
- 欢迎提交 [Issue](https://github.com/chengfang77777-cell/ai-girlfriend/issues) 与 PR

如果这个项目对你有帮助，欢迎点亮 ⭐ Star，谢谢支持！
