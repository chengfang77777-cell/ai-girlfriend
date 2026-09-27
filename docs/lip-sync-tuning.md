# 第一阶段口型调参

本阶段仍使用音频频谱推算五种元音，不识别实际音素。主要改善开合幅度、稳定性、静音闭嘴和形状过渡。

参数集中在 `assets/web/js/lip-sync.js` 的 `DEFAULT_CONFIG`，RMS 使用归一化 PCM，时间单位为秒。

| 参数 | 默认值 | 调整方向 |
| --- | --- | --- |
| `maxWeight` | 0.72 | 五种口型的总权重预算；嘴张得太大时降低 |
| `caps` | 按口型设置 | 单个口型的上限；用于限制某个模型容易穿帮的形状 |
| `fullScaleRms` | 0.16 | 达到最大幅度的音量；整体嘴张得太小时降低 |
| `gateOpenRms` | 0.012 | 开始驱动的音量门限；轻声漏掉时适当降低 |
| `gateCloseRms` | 0.006 | 收嘴门限；需小于开口门限 |
| `gateHoldSeconds` | 0.045 | 短静音期间保留门限状态的时间；音量包络仍立即开始收嘴 |
| `attackSeconds` | 0.035 | 开口的响应时间常数；越小越快 |
| `releaseSeconds` | 0.085 | 有声但音量降低时的收口时间常数 |
| `silenceReleaseSeconds` | 0.045 | 静音时的收口时间常数；越小收得越快 |
| `shapeSeconds` | 0.055 | 元音形状过渡时间常数；太小容易跳变，太大会拖拍 |

建议用相同角色、音色、语速和测试句逐项调整，每次只改一个参数。先调幅度，再调开合速度，最后调形状过渡。

测试句：`爸爸妈妈，阿姨来了。乌云慢慢散开，我们一起出去吧。` 另外观察轻声、长元音、句中停顿、连续播放和手动停止。b/p/m 的精准闭唇需要后续音素时间轴支持，不能用本阶段的效果作为识别准确率。

验证和构建：

```powershell
node --test test/lip_sync_test.cjs
& 'D:\AIcursorclaude\flutter3245\bin\flutter.bat' test
& 'D:\AIcursorclaude\flutter3245\bin\flutter.bat' build windows --release
```

运行 `build/windows/x64/runner/Release/ai_girlfriend.exe`。移动应用时需要保留整个 Release 目录中的 DLL 和 data 目录。每次启动查看器都会覆盖本地缓存的口型脚本，确保新构建的参数生效。
