# 聊天情绪字段与输入焦点修复

## 表情根因和修复

用户实际聊天最近 12 条回复的 emotion 全是 neutral。使用隔离的数据副本、原角色和原历史，向当前 DeepSeek 发出一条合成的庆祝测试消息：HTTP 200，但原始返回只有 19 字的普通文字，没有 emotion 字段。现有解析兜底将其保存为 neutral。此前渲染测试直接注入 happy 等情绪，无法覆盖这个上游问题。

请求仅靠提示词要求 JSON，没有启用服务端 JSON 输出约束；历史 assistant 消息又被转换成纯文字，丢失已保存的 emotion/action。修复将历史 assistant 恢复为 reply/emotion/action JSON，并加入 response_format=json_object。用户消息仍是普通文字，历史存储无需迁移。

同一历史、同一测试消息再次真实调用：原始返回合法 JSON，emotion=happy，action=clap；解析后保留 happy。没有通过增加笑脸强度或将中立回答强制改成开心来处理。

两家当前支持的对话接口均支持 JSON 输出模式：
- https://api-docs.deepseek.com/guides/json_mode/
- https://mimo.mi.com/docs/en-US/quick-start/usage-guide/text-generation/structured-output

## 输入焦点

Flutter 默认的 send 编辑完成行为会取消焦点。原实现只在成功发送后重新请求焦点，空文本或正在等待回复时会漏掉。修复包括首次 autofocus、覆盖编辑完成的默认取消焦点行为、空白区域点击保留焦点、窗口恢复时谨慎恢复输入，以及焦点边框跟随状态变化。其他输入框和弹窗可以正常获得焦点；等待回复时可以继续写下一条草稿，回车不会丢弃草稿或重复发送。

## 验证

- 修改前重现 2 个情绪协议测试失败，以及 5 类焦点失败。
- 修改后 Flutter 全套 42 项通过，相关 6 个 Dart 文件静态检查无问题。
- tool/expression_diagnose_test.dart 的真实接口检查仅使用临时数据副本，不保存测试对话。
- tool/windows_chat_probe.dart 是原目录 Windows Release 的独立联调入口：在临时存储和模拟 HTTP 下，经实际 TextInputAction.send、HomePage、消息解析/存储、WebView 脚本传递，检查 7 种非中立表情及淡回中立，并检查等待中的焦点与草稿。最终交付必须重建为 lib/main.dart 正式入口。
- Windows 原生联调退出码 0：happy/shy/angry/sad/surprised/refuse/thankful 全部通过，实际表情通道峰值约 0.26–0.41；每条回复后均按时归零，焦点与等待中的草稿保留正常。日志在 Documents/windows-chat-probe.log。此验证使用真实 HomePage 和 WebView，HTTP 为可控测试响应；上面的 DeepSeek 请求另外验证真实服务返回协议。
- 已用 Flutter `D:\AIcursorclaude\flutter3245`、正式入口 `lib/main.dart` 重新构建 Windows Release，产物仍在原目录 `build/windows/x64/runner/Release/ai_girlfriend.exe`。

语音合成的超时、重试、音色与代理策略本轮不调整，仍等待用户此前要求的处理选择。
