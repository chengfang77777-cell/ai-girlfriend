# 滚轮与固定角色音色

## 使用方式

- 普通滚轮滚动消息；Ctrl + 滚轮缩放模型。左右 Ctrl 均支持。
- 鼠标拖拽旋转及移动端触摸缩放沿用已有控制。
- 每个有音色描述的角色第一次说话时，先生成一段独立的参考语音，再使用参考语音合成实际回复。首次等待时间会增加。
- 参考音频以角色 ID 隔离，存入应用现有 Hive 设置存储，重启后复用。
- 音色描述改变时重新生成参考；同一段描述的后续回复始终使用原始参考，不把合成回复反复当作新参考。
- 复刻失败会走现有错误提示，不自动切换到新的设计音色。

## 实现

`ChatWheelRegion` 在 Flutter 内判断 Ctrl；Windows 的原生滚轮转发被查看器捕获，避免重复缩放和丢失修饰键。缩放指令直接调整相机与目标之间的距离，并遵守原有距离上下限。

`TtsService.speakWithStableVoice` 使用 `mimo-v2.5-tts-voicedesign` 建立参考，随后使用 `mimo-v2.5-tts-voiceclone`，通过 `audio.voice` 传入带 `data:audio/wav;base64,` 前缀的固定样本。参考格式与大小在保存前检查，同角色并发首次请求共享参考生成任务。

接口依据：[MiMo 官方语音合成说明](https://mimo.mi.com/docs/zh-CN/quick-start/usage-guide/audio/speech-synthesis-v2.5)。固定参考旨在减少音色漂移，不保证不同文本的语气、情绪或音高完全一致。

## 验证

- `node --test test/lip_sync_test.cjs test/viewer_wheel_test.cjs`：18 项通过。
- `D:\AIcursorclaude\flutter3245\bin\flutter.bat test`：11 项通过。
- 音色测试使用模拟 HTTP 响应，覆盖跨存储重开复用、角色隔离、描述变更、并发生成、失败不换声、无效音频与过期播放结果；未调用真实 TTS 接口验证听感。
- 使用指定的 Flutter 3.24.5 在原工作区编译 Windows Release。窗口关闭后残留的旧应用进程经用户授权结束。
