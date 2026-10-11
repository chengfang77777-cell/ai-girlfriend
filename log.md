# ai_girlfriend_vrm 变更日志

## 2026-08-29

### 1. 密钥泄露排查（只读审计，未改动任何 Git 内容）

- 发现：两个远程仓库均为公开仓库（GitHub `chengfang77777-cell/ai-girlfriend`、Gitee `chengfang77777/aigirlfriend`），master 分支源码中存在两处硬编码 API Key：
  - `lib/data/storage_service.dart`（DeepSeek Key）
  - `lib/data/tts_service_web.dart`（MiMo TTS Key）
- 另发现：GitHub 仓库中 `build/app/outputs/flutter-apk/app-release.apk` 以 Git LFS 指针形式入库（本体约 161MB），AOT 产物内的字符串常量存在二次泄露面；Gitee 侧无该 APK（免费仓库不支持 LFS）。
- 本地 `lib/core/secrets.dart` 已被 `.gitignore` 忽略，且从未进入任何提交历史（`git log --all` 无记录），此部分无泄露。
- 处置：用户已在控制台吊销全部在用 Key；远程历史清理（filter-repo / BFG + force push）与 LFS 中的旧 APK 删除尚未执行，待用户确认后进行。

### 2. 新增功能：设置页支持自定义 MiMo TTS API Key

- `lib/core/constants.dart`：新增 `mimoApiKeyKey = 'mimo_api_key'`。
- `lib/data/storage_service.dart`：新增 `mimoApiKey` 读取访问器，并在 `init()` 中按 DeepSeek Key 的同款逻辑回填内置默认值。
- `lib/data/tts_service.dart`（桌面/移动端）与 `lib/data/tts_service_web.dart`（Web 端）：
  - 移除编译期常量 Key，改为运行时解析，优先级为「运行时注入 `apiKeyOverride` > 设置页保存的用户 Key > `secrets.dart` 内置 Key」。
  - 新增 `hasApiKey` 访问器；未配置密钥时直接返回空（Web 端回退到 Web Speech API），并输出提示日志。
- `lib/presentation/pages/settings_page.dart`：
  - 抽出通用组件 `_buildApiKeyCard`（标题/图标/输入框/显隐切换/保存/配置状态点/说明文案）。
  - 在「DeepSeek API Key」卡片下方新增「MiMo TTS API Key」卡片，保存后立即写入 Hive 并对后续 TTS 请求生效。
  - 修复原卡片输入时配置状态点不刷新的问题（`onChanged` 触发 `setState`）。

### 自检结果

- `flutter analyze`：19 条 info/warning，**0 error**；新增文件无告警（剩余告警均为既有代码）。
- `flutter build windows --debug`：构建成功，产物 `build\windows\x64\runner\Debug\ai_girlfriend.exe`（输出中 "Nuget is not installed" 为环境提示，不影响构建结果）。

### 3. 清空内置密钥（方案 A）

- `lib/core/secrets.dart` 中 `deepseekApiKey` / `mimoApiKey` 均置为空字符串，代码库内不再保留任何密钥明文。
- 影响：应用不再携带内置兜底 Key，密钥 100% 由设置页输入并存入本地 Hive。
- 注意：已安装过旧版本的应用，其 Hive 中仍残留已吊销的旧 Key，需用户在设置页清空后重新填入新 Key（卸载重装或清数据亦可）。
- 复检：`flutter analyze` 仍为 19 条 info/warning、0 error，与改动前一致。

### 4. 角色列表预设卡片底部溢出修复

- 现象：角色管理页预设角色横排列表底部出现黄黑 overflow 指示条（"BOTTOM OVERFLOWED BY 5-8 PIXELS"）。
- 根因：[lib/presentation/pages/character_list_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/character_list_page.dart) 用 `SizedBox(height: 220)` 强制约束横向 ListView 高度，在系统文字放大或标签换行时卡片自然高度超过 220，触发溢出。
- 修复：将固定高度从 `220` 调为 `250`，留出富余空间以适配文字缩放与标签换行。
- 复检：`flutter build windows --debug` 构建成功，产物 `build\windows\x64\runner\Debug\ai_girlfriend.exe`。

### 5. 新增小米 MiMo 对话模型（可替换 DeepSeek）

- 新增 [lib/data/llm_provider.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/data/llm_provider.dart)：声明式供应商配置（id / 名称 / baseUrl / 模型名 / 认证头类型 / 生成长度参数名），内置 `LlmProvider.deepseek` 与 `LlmProvider.mimo` 两个常量，并提供 `fromId` 回退。
- [lib/core/constants.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/core/constants.dart)：新增 `mimoBaseUrl`、`mimoChatModel = 'mimo-v2.5-pro'`、`llmProviderKey`。
- [lib/data/deepseek_api.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/data/deepseek_api.dart)：改为配置驱动，新增可选参数 `provider`（默认 DeepSeek，向后兼容）；`_buildApiUrl` 用 `provider.baseUrl`，`_buildRequestBody` 用 `provider.model` 并按供应商选择 `max_tokens` / `max_completion_tokens`，`_buildHeaders` 按供应商选择 `Authorization: Bearer` / `api-key`。**提示词构建与回复后处理（system prompt、上下文窗口、情绪/动作修正、括号清理、JSON 解析）完全复用同一份代码，两个供应商行为一致。**
- [lib/domain/chat_provider.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/domain/chat_provider.dart)：新增 `llmProviderProvider`；原 `deepseekApiProvider` 更名为 `llmApiProvider`，按当前供应商取对应 Key（MiMo 复用 TTS 的 MiMo Key，DeepSeek 用 DeepSeek Key）。
- [lib/presentation/pages/home_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/home_page.dart)：同步新 provider 名，未配置 Key 时的提示文案随供应商动态变化。
- [lib/presentation/pages/settings_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/settings_page.dart)：新增「对话模型」选择卡片（DeepSeek / 小米 MiMo，单选并写入 Hive）；MiMo Key 说明改为「用于语音合成与 MiMo 对话模型」；关于页「AI 模型」显示当前供应商与模型名。
- 模型选型依据：官方文档 [模型列表](https://mimo.mi.com/docs/zh-CN/quick-start/summary/model)（2026-07-15 更新）与 [首次调用 API](https://mimo.mi.com/docs/zh-CN/quick-start/summary/first-api-call)（2026-07-16 更新）——V2 系列（mimo-v2-pro / flash）已于 2026-06-30 下线，当前文本模型为 `mimo-v2.5-pro`（推理/长文本）与 `mimo-v2.5`（全模态）；OpenAI 兼容 base_url 为 `https://api.xiaomimimo.com/v1`，认证头为 `api-key`。

### 自检结果（本轮）

- `flutter analyze`：19 条 info/warning，**0 error**（与改动前基线一致）。
- `flutter test test/llm_provider_test.dart`：3 项全部通过（DeepSeek/MiMo 配置值、`fromId` 回退逻辑）。
- `flutter build windows --debug`：构建成功，产物 `build\windows\x64\runner\Debug\ai_girlfriend.exe`。

### 6. 修复「对话模型无法切换到 MiMo」

- 现象：设置页点选「小米 MiMo」后选中态立刻弹回 DeepSeek，实际调用仍是 DeepSeek。
- 根因：`llmProviderProvider` 原本是普通 `Provider`，其结果**只计算一次并永久缓存**。虽然 `onChanged` 已把选择写入 Hive，但重建时 `ref.read` 拿到的仍是缓存中的 `deepseek`。（音色选择能正常切换，是因为它每次 build 直接用 `storage.getSetting` 实时读 Hive，未经过 Provider 缓存。）
- 修复：
  - [lib/domain/chat_provider.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/domain/chat_provider.dart)：`llmProviderProvider` 由 `Provider` 改为 `StateProvider`，初始值仍从本地存储读取。
  - [lib/presentation/pages/settings_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/settings_page.dart)：改用 `ref.watch` 监听供应商状态；`onChanged` 中 `await` 写入 Hive 后同步更新 `ref.read(llmProviderProvider.notifier).state`，使 `llmApiProvider` 与 `chatNotifierProvider` 自动重建，切换即时生效且重启后保持。
- 复检：`flutter analyze` 19 条 info/warning、0 error；`flutter build windows --debug` 构建成功。

### 7. MiMo 默认模型降配 + 清除聊天记录功能

- 模型降配：`AppConstants.mimoChatModel` 由 `mimo-v2.5-pro` 改为 `mimo-v2.5`（性价比更高），`LlmProvider.mimo` 的说明文案同步更新；单元测试断言同步为 `mimo-v2.5`。需要更强推理时，只需把该常量改回 `mimo-v2.5-pro`。
- [lib/data/storage_service.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/data/storage_service.dart)：新增 `clearAllMessages()`，清空 messages Box 与内存缓存。
- [lib/domain/chat_provider.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/domain/chat_provider.dart)：`ChatNotifier` 新增 `clearChat(characterId)` 与 `clearAllChats()`。
- [lib/presentation/widgets/character_card.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/widgets/character_card.dart)：新增 `onClearChat` 回调与「清除聊天记录」菜单项（带二次确认对话框）；菜单显示条件由「非预设角色」改为「提供了任一操作」，因此**预设角色也支持清除聊天记录**。
- [lib/presentation/pages/character_list_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/character_list_page.dart)：预设角色与自定义角色卡片均接入 `onClearChat`，清完后刷新消息并弹出提示。
- [lib/presentation/pages/settings_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/settings_page.dart)：关于卡片下方新增红色「清除所有聊天记录」入口，点击弹出二次确认（`AlertDialog`，取消 / 确定清除），确认后清空全部角色记录并刷新。

### 自检结果（本轮）

- `flutter analyze`：19 条 info/warning，**0 error**（与基线一致）。
- `flutter test test/llm_provider_test.dart`：3 项全部通过（DeepSeek 配置、MiMo 配置含新模型名 `mimo-v2.5`、`fromId` 回退）。
- `flutter build windows --debug`：构建成功，产物 `build\windows\x64\runner\Debug\ai_girlfriend.exe`。

### 8. 聊天页（每个角色界面）新增清除聊天记录按钮

- [lib/presentation/pages/home_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/home_page.dart)：AppBar `actions` 最左侧新增「清除聊天记录」圆形按钮（`Icons.delete_sweep_outlined`，未选择角色时置灰不可点，样式与切换角色/设置按钮一致）。
- 点击后弹出二次确认，文案明确「仅清除该角色的对话，其他角色的记录不受影响」；确认后调用 `ChatNotifier.clearChat(character.id)` 只清当前角色，刷新消息列表并提示。
- 与已有入口的关系：角色管理页卡片菜单的「清除聊天记录」（针对选中角色）与设置页的「清除所有聊天记录」（全部角色）保持不变，三个入口各有分工。

### 自检结果（本轮）

- `flutter analyze`：19 条 info/warning，**0 error**（与基线一致，新增代码无告警）。
- `flutter build windows --debug`：构建成功，产物 `build\windows\x64\runner\Debug\ai_girlfriend.exe`。

### 9. Release 构建（Windows + Android）

使用 SDK：`D:\AIcursorclaude\flutter3245`（与 `android/local.properties` 中的 `flutter.sdk` 一致）。

- `flutter build windows --release` → `build\windows\x64\runner\Release\ai_girlfriend.exe`，构建成功。
- `flutter build apk --release --split-per-abi` → 三个分包，均构建成功：
  - `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`（约 130.8MB，主流手机用这个）
  - `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk`（约 128.4MB，老款 32 位机型）
  - `build\app\outputs\flutter-apk\app-x86_64-release.apk`（约 131.9MB，模拟器/个别平板）

注意事项：

1. APK 体积大（约 130MB）是因为 assets 内含 VRM 模型与 WebView 前端资源。**分发走 GitHub Releases（免费单文件上限 2GB），不要用 Git 仓库托管**——Gitee 免费仓库不支持 LFS 且有单文件 100MB 限制，且历史上已有 APK 误入 Git 的教训。
2. 当前 release 使用 debug 签名（`android/app/build.gradle` 中 `signingConfig = signingConfigs.debug`），可正常安装自用，上架应用商店前需配置正式签名。
3. 由于内置密钥已清空（`secrets.dart` 为空），**新安装的应用首次使用必须在「设置」中填入 DeepSeek / MiMo API Key**，否则发消息会提示去设置页配置。
4. 构建产物均位于 `build/` 目录，已被 `.gitignore` 排除，不会被提交。

### 10. Git 提交与发布（用户授权执行）

**执行前备份**：`D:\AIcursorclaude\ai_girlfriend_vrm_backup_20260829.bundle`（`git bundle create --all`，237.9MB，含全部 refs，可用于回滚）。

**步骤与结果**：

1. `git fetch --all` 拉取远程最新，发现 GitHub 有 2 个本地没有的提交（`f29b86c Update README.md`、`e9ece1b github--version_1.0`），先整合再推送，避免覆盖。
2. 工作区改动提交为 `0daf614 version_2`（含删除旧 APK、新增 `llm_provider.dart` / `log.md` / `llm_provider_test.dart`）。
3. `git merge -X ours github/master` 合并 GitHub 独有提交（`.gitattributes` / `README.md` / `README_EN.md` 的更新）。
4. `git-filter-repo --invert-paths --path build/app/outputs/flutter-apk/app-release.apk --force`：把 161MB 的 APK（LFS 指针）从**全部提交历史**中彻底移除。15 个 commit 被重写，新 HEAD `503a840`。
5. 校验：`git log --all -- <apk 路径>` 为空、`git ls-files` 无 .apk、工作区无该文件。
6. Force push 到两个远程（本地 `dev_cf` → 远程 `master`）：
   - GitHub：`f29b86c...503a840 forced update`
   - Gitee：`6f6e6cc...503a840 forced update`
   - 两个远程 master 现均为 `503a8401c34e3868a79f2d935a69d826d23a355e`
7. `git lfs prune` 清理本地 LFS 中已无引用的旧 APK 对象（161MB）。

**网络处理**：GitHub 的 SSH（22 端口）被网络层掐断，改用 HTTPS + `gh` 凭据临时认证完成 fetch/push，未修改全局 git config。

**发布**：GitHub Release `version_2` 已创建并上传三个 APK
<https://github.com/chengfang77777-cell/ai-girlfriend/releases/tag/version_2>

### 待办

- GitHub 服务端 Git LFS 中仍存有那个 161MB 的旧 APK 对象（历史引用已清除，本地副本已 prune）。若 LFS 存储/流量配额紧张，需在 GitHub 仓库 Settings 的 Git LFS 管理界面手动删除该对象。
- 历史提交中仍残留两处**已吊销**的 API Key 明文（`storage_service.dart`、`tts_service_web.dart` 的旧版本）。密钥已在控制台吊销，风险已解除；如需从历史中一并抹除，可再跑一次 `git-filter-repo --replace-text` 并重新 force push（需再重写一次历史）。
- 当前 release 使用 debug 签名，上架应用商店前需配置正式签名。
- 本机 log.md 的本次记录尚未提交，下次提交时一并推送。

## 2026-10-11 10:28:00

### 11. Git 规范与忽略策略升级（.gitattributes & .gitignore）

- **背景与根因**：
  - Windows 环境下修改代码频发 `LF will be replaced by CRLF` 告警，跨平台换行符未统一。
  - 项目包含数十个 VRM 模型与 VRMA 动作等大文件资产，缺乏显式 `binary` 声明，存在意外换行符损坏或文本 diff 性能损耗风险。
  - 本地生成了 `.codebuddy/` 等 AI 工具目录，且新增本地包 `packages/webview_windows` 后的子模块构建目录（`build/`、`.dart_tool/`）未被递归忽略。
- **改动成果**：
  - 更新 [.gitattributes](file:///d:/AIcursorclaude/ai_girlfriend_vrm/.gitattributes)：全局启用 `* text=auto`；跨平台源码与文本文件（Dart、JS、C++、CMake、Python、HTML 等）统一 `eol=lf`；Windows 批处理保持 `eol=crlf`；VRM、VRMA、GLB、PNG、WAV、TTF、APK、DLL 等资产显式声明为 `binary`。
  - 更新 [.gitignore](file:///d:/AIcursorclaude/ai_girlfriend_vrm/.gitignore)：保留既有全部规则；补全 AI/现代编辑器目录（`.codebuddy/`、`.cursor/`、`.windsurf/`）；补全 Visual Studio 深度忽略（`.vs/`、`*.vcxproj.user`）；改用递归规则（`build/`、`**/build/`、`**/.dart_tool/`）覆盖子包；补全 Python 缓存（`__pycache__/` 等）、Node 依赖（`node_modules/`）及 Android 签名凭据兜底（`key.properties`、`*.keystore`、`*.jks`、`*.aab`、`local.properties`）。
- **自检与验证**：
  - `git check-ignore -v` 实测：`.codebuddy/`、`.vs/`、`packages/webview_windows/.dart_tool/` 均精准命中。
  - `git check-attr -a` 实测：VRM/VRMA 文件正确识别为 `binary: set`，Dart/C++ 正确生效 `eol: lf`。

### 12. 移动端体验对齐与 Android Release 构建（2026-10-11 10:37:00）

- **背景与改动**：
  - 为了让手机端与 Windows 版功能表现完全一致，在 [lib/presentation/widgets/avatar_display.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/widgets/avatar_display.dart) 中补齐移动端支持：
    - `startHighFive()` 补齐移动端 `_mobileCtrl` 处理，支持通过 `runJavaScriptReturningResult` 触发击掌互动。
    - 移动端 WebView 初始化 `loadRequest` URL 增加 `background` 与 `motion` 查询参数，确保首帧即呈现指定背景与动态。
- **构建结果**：
  - 使用 Flutter SDK `D:\AIcursorclaude\flutter3245` 执行 `flutter build apk --release --split-per-abi` 构建成功：
    - [app-arm64-v8a-release.apk](file:///d:/AIcursorclaude/ai_girlfriend_vrm/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)：131.0 MB（主流 Android 手机使用）
    - [app-armeabi-v7a-release.apk](file:///d:/AIcursorclaude/ai_girlfriend_vrm/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk)：128.6 MB（32 位老款机型）
    - [app-x86_64-release.apk](file:///d:/AIcursorclaude/ai_girlfriend_vrm/build/app/outputs/flutter-apk/app-x86_64-release.apk)：132.1 MB（模拟器/部分平板）
- **自检验证**：
  - `flutter test test/high_five_control_test.dart`：8 项测试全部通过。
  - `assembleRelease` 编译耗时 92.6s，产物完整落盘。

### 13. 中英双语文档同步与二进制产物入库安全审计（2026-10-11 10:40:00）

- **成果**：
  - 更新 [README.md](file:///d:/AIcursorclaude/ai_girlfriend_vrm/README.md) 与 [README_EN.md](file:///d:/AIcursorclaude/ai_girlfriend_vrm/README_EN.md)：
    - 功能特性全面覆盖：DeepSeek + 小米 MiMo 双大模型切换、专注伴读模式与静音机制、伴读音乐/白噪音、击掌互动（High-Five）、8 组动态粒子伴读背景、单角色/全局聊天记录清空。
    - 发布说明补充：补充分架构 APK（ARM64 / ARMv7 / x86_64）编译指南与规范，明确二进制包走 GitHub Releases 发布。
  - **Git 仓库二进制安全审计**：
    - `git check-ignore -v` 验证确认：`build/app/outputs/flutter-apk/*.apk` 与 `build/windows/x64/runner/Release/*.exe` 100% 命中 `.gitignore` 的 `build/` 与 `*.apk` 规则。
    - `git status` 与 `git ls-files` 验证确认：当前 Git 工作区与暂存区没有任何 `.apk` 或 `.exe` 文件，推送到远程仓库时**绝对不会包含任何二进制安装包**，彻底杜绝仓库臃肿或触发 Gitee 100MB 限制。

### 14. 产物精简：仅保留主流架构 arm64-v8a 安装包（2026-10-11 10:44:00）

- **成果**：
  - 严格遵循系统安全删除规范，使用回收站安全删除机制将 `app-armeabi-v7a-release.apk` 与 `app-x86_64-release.apk`（含 sha1 校验文件）移入 Windows 系统回收站。
  - 当前 `build/app/outputs/flutter-apk/` 目录下仅保留现代 Android 手机专属的 [app-arm64-v8a-release.apk](file:///d:/AIcursorclaude/ai_girlfriend_vrm/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)（131.0 MB）。

### 15. 手机端学习伴读功能解除平台限制与重新编译（2026-10-11 10:58:00）

- **排错根因**：
  - [lib/presentation/pages/home_page.dart](file:///d:/AIcursorclaude/ai_girlfriend_vrm/lib/presentation/pages/home_page.dart) 顶栏的「陪我学习」入口此前遗留了 `if (Platform.isWindows && character != null)` 判定，击掌控制组件同样遗留了 `Platform.isWindows`，导致在 Android 手机端这两项功能被硬编码隐藏。
- **改动成果**：
  - 彻底移除 `Platform.isWindows` 限制，使伴读模式、白噪音音乐与击掌互动在移动端与 Windows 端完全统一呈现。
  - 适配移动端手势提示文案为「单指拖动转身 · 双指缩放」。
  - 使用 Flutter SDK `D:\AIcursorclaude\flutter3245` 重新编译，多余分包移入回收站，输出最新的主流真机安装包 [app-arm64-v8a-release.apk](file:///d:/AIcursorclaude/ai_girlfriend_vrm/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)（131.2 MB，10:57 最新编译）。




