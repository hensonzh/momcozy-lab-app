# Agent 语音播报与恢复

## 参考与边界

重新阅读设计工程 `UserApp.tsx` 的语音会话、toolbar 和 neutral toast，以及 `styles.css` 2041–2048、2185–2188、2742 / `styles/me-agent.css` 的覆盖。原稿与现有 App 均为回复播报，没有录音或转写入口；本轮不添加新语音业务。隔离本地浏览器中的开关参考为 `design-voice-on.png` / `design-voice-off.png`，计算尺寸保存在 `design-metrics.json`，未访问远程 API。

## 修改

- 开关文案明确为实时语音播报，补齐 switch 的开关语义；播报启动时提供 AI 合成语音的辅助功能状态。原生播放器目前只提供完成/失败回调，因此使用“播报已启动”，不把请求启动误报成已经听到音频。
- 失败后显示设计中的轻量提示、播放回复和关闭入口，使用统一 Agent 色彩、11 正文、13 操作文字、12 圆角和至少44触控；不向用户展示服务内部错误。
- 重播沿用当前问候或回复的现有播放器，保留通知优先级与取消机制，不重新发送 Agent 请求。生成回复期间禁用重播，关闭语音会取消播放；新一轮清除旧错误。
- 捕获播放器同步启动异常，避免异常中断页面。错误状态用独立监听刷新，不要求整个对话因语音进度重建。
- 小屏/大字号时提示与操作纵向排列；可用高度小于600且有语音错误时收起次要快捷提问，保留阅读、恢复和输入。修复键盘约束下的31像素溢出。

## 验证

- `before.txt`：播放失败后缺少恢复入口的复现；`component.txt`：9项针对性测试，含320/390/430×1x/2x的36张状态金图及1张键盘约束金图。核对问候失败、关闭提示、流式生成期间失败、完成后重播、开关取消、同步启动失败和内部错误不外露。
- 重播测试断言文本不变、会话请求次数不增加、关闭语音取消当前播放，以及重新开启开关不会重复播报旧回复。
- `regression.txt`：587项Agent、媒体、流式和共享组件测试通过，包含原有流式语音分段、通知优先级、会话切换与取消保护。`analyze.txt`：相关文件静态检查无问题。

测试使用可控音频播放器和事件流，验证UI及现有播放调用边界，不代表远程语音合成、扬声器音质或模型鉴权已通过。当前Agent环境限制继续保留在首页整体验收项中。

`native.txt`: Android verification passed with 12 screenshots across 1x/2x. Inspected failure layout, enabled/disabled replay, dismiss, toggle off/on and normal conversation readability. The playback and event providers are controlled fixtures; real audio synthesis is not claimed.

`build.txt` / `install.txt`: ordinary local Debug App rebuilt and installed. Mia is restored on the authenticated Me screen (`native-restored-home.png/xml`). Changes remain uncommitted.
