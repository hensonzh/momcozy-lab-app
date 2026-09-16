# Cozymate 资料卡到续购和媒体查看器

从已登录 More 页点击 Cozymate，输入问题并发送，接收隔离 SSE 的 `artifact.created` 和完成事件；卡片、事件解析、runner、dispatcher、App 路由、资源 Repository、图片解码和视频控件均使用正式实现。通过公开 `agentHubBuilder` 注入测试 SSE/HTTP/会话/语音依赖，沿实际卡片按钮进入页面。没有直接设置媒体路由或挂载目标页面来替代来源点击。

新增 **35 个状态、68 个窗口、23 张完整长图变体（11 张主长图）**。四条主要流程各覆盖 393/1x 和 320/2x，另一个失效资源动作在 393 验证；共 9 项严格测试通过。默认 24 条路由现在均有至少一个真实入口链观察点，但这不证明全体页面状态、按钮和系统层已经覆盖。

## 已验证的正常路径

1. **无参数续购**：SSE 资料卡的 `/services/renew` 内部链接被正式 mapper/dispatcher 识别，进入未指定旧服务的四方案列表；初始没有指定套餐高亮。选择后打开购买前确认，关闭后选中状态保留。由于 dispatcher 使用 `go`，点击续购“返回”实际落到 `/me`，再点击 Cozymate 可恢复原回复及卡片，未再次发送模型请求。
2. **图片**：点击稳定 `/v1/assets/:id?kind=image` 动作，进入加载状态；503 后显示重试，重新请求成功后实际解码本地 PNG 字节。双击放大到 2.5x、拖动平移、再次双击恢复 1x 均通过指针操作及变换矩阵验证。返回 Cozymate 保留原卡，再次打开同一图片命中 Repository 内存缓存，没有新增资产 HTTP。
3. **PDF**：资料卡进入正式 PDF 查看器后，加载、503 错误、重试挂起均可见。读取挂起时返回仍恢复原卡；迟到的失败响应没有产生页面异常。再次打开遇到 403 时仍呈现可重试的失败页。PDF 正文解码、分页和文档缩放已有独立 Android 原生证据，本轮没有将它们描述为在这条链中重新执行。
4. **视频**：资料卡进入视频查看器，定向注入该网络视频的初始化失败；重试后使用实际 VideoPlayerController 与控件。播放/暂停、进度跳转、静音、全屏/退出、播放中断后重试、返回及 controller 释放均有断言和截图。资产地址及认证头由正式 Repository 构造；原生纹理和解码器用现有测试平台隔离，截图黑色区域不代表正常视频帧。
5. **失效资源动作**：资料卡可展示指向不符合稳定资产契约的动作，但点击后 `_isStableProductAssetAction` 拒绝导航，留在原卡且不请求资产，没有自动进入“缺少资源参数”页。不能用该错误卡去证明缺参数页有正常入口。

## 状态与实际触发

| 状态 | 实际操作 / 条件 | 窗口、长图和前驱 |
| --- | --- | --- |
| image-cached | Reopen same image → in-memory cache, no additional asset HTTP | [证据](../05-agent/agent-resource-journey-image-cached/README.md) |
| image-card | More → Cozymate → send request → real SSE artifact presents 查看示意图片 | [证据](../05-agent/agent-resource-journey-image-card/README.md) |
| image-error | Image HTTP 503 → retry state in actual viewer | [证据](../05-agent/agent-resource-journey-image-error/README.md) |
| image-loaded | Retry decodes actual local PNG bytes through ProductAssetRepository | [证据](../05-agent/agent-resource-journey-image-loaded/README.md) |
| image-loading | Tap stable image asset action → actual viewer waiting for authenticated bytes | [证据](../05-agent/agent-resource-journey-image-loading/README.md) |
| image-panned | Drag zoomed image → translated content | [证据](../05-agent/agent-resource-journey-image-panned/README.md) |
| image-reset | Double tap zoomed image → reset to fit | [证据](../05-agent/agent-resource-journey-image-reset/README.md) |
| image-return | Viewer back without pop stack → Cozymate with original image card | [证据](../05-agent/agent-resource-journey-image-return/README.md) |
| image-zoomed | Double tap actual image → 2.5x zoom | [证据](../05-agent/agent-resource-journey-image-zoomed/README.md) |
| invalid-card | More → Cozymate → send request → real SSE artifact presents 查看失效资料 | [证据](../05-agent/agent-resource-journey-invalid-card/README.md) |
| invalid-no-navigation | Tap malformed asset action → stable asset guard ignores it, no missing-resource page forced | [证据](../05-agent/agent-resource-journey-invalid-no-navigation/README.md) |
| pdf-card | More → Cozymate → send request → real SSE artifact presents 阅读资料 PDF | [证据](../05-agent/agent-resource-journey-pdf-card/README.md) |
| pdf-error | PDF HTTP 503 → actual retry control | [证据](../05-agent/agent-resource-journey-pdf-error/README.md) |
| pdf-forbidden | Reopen after failed pending read → asset denied 403, still retryable | [证据](../05-agent/agent-resource-journey-pdf-forbidden/README.md) |
| pdf-loading | Tap stable PDF action → viewer requests authenticated PDF | [证据](../05-agent/agent-resource-journey-pdf-loading/README.md) |
| pdf-pending-return | Back while PDF read pending → original Cozymate reply | [证据](../05-agent/agent-resource-journey-pdf-pending-return/README.md) |
| pdf-retrying | Retry PDF → request pending again | [证据](../05-agent/agent-resource-journey-pdf-retrying/README.md) |
| renew-back-mom | Renewal back after artifact context.go → actual /me fallback | [证据](../05-agent/agent-resource-journey-renew-back-mom/README.md) |
| renew-card | More → Cozymate → send request → real SSE artifact presents 继续查看支持方案 | [证据](../05-agent/agent-resource-journey-renew-card/README.md) |
| renew-card-return | Tap Cozymate → original reply and resource card restored | [证据](../05-agent/agent-resource-journey-renew-card-return/README.md) |
| renew-closed | Close eligibility → selected package retained | [证据](../05-agent/agent-resource-journey-renew-closed/README.md) |
| renew-eligibility | Choose first package → real purchase eligibility | [证据](../05-agent/agent-resource-journey-renew-eligibility/README.md) |
| renew-list | Tap supported internal artifact link → real renewal route without episode parameter | [证据](../05-agent/agent-resource-journey-renew-list/README.md) |
| video-card | More → Cozymate → send request → real SSE artifact presents 播放指导视频 | [证据](../05-agent/agent-resource-journey-video-card/README.md) |
| video-error | Tap stable video action → actual player reports isolated platform initialization failure | [证据](../05-agent/agent-resource-journey-video-error/README.md) |
| video-exit-fullscreen | Exit immersive route → same inline controller and position | [证据](../05-agent/agent-resource-journey-video-exit-fullscreen/README.md) |
| video-fullscreen | Fullscreen button → actual immersive route; platform orientation request isolated | [证据](../05-agent/agent-resource-journey-video-fullscreen/README.md) |
| video-muted | Mute → volume icon and controller value change | [证据](../05-agent/agent-resource-journey-video-muted/README.md) |
| video-paused | Tap pause → playback paused | [证据](../05-agent/agent-resource-journey-video-paused/README.md) |
| video-playing | Tap play → controller playing state | [证据](../05-agent/agent-resource-journey-video-playing/README.md) |
| video-ready | Retry initializes controller; actual controls rendered, native texture isolated | [证据](../05-agent/agent-resource-journey-video-ready/README.md) |
| video-recovered | Retry playback error → newly initialized controller | [证据](../05-agent/agent-resource-journey-video-recovered/README.md) |
| video-return | Media back → original card; video controller disposed | [证据](../05-agent/agent-resource-journey-video-return/README.md) |
| video-runtime-error | Platform playback error → retry state; failed controller disposed | [证据](../05-agent/agent-resource-journey-video-runtime-error/README.md) |
| video-seeked | Tap progress → seek position updates | [证据](../05-agent/agent-resource-journey-video-seeked/README.md) |

## 验证记录

- [最终严格采集](runs/20260913T155132-targeted/capture.log)：9 PASS；没有在采集时更新 Golden 或放宽容差。
- [静态检查](agent-resource-analyze.log)：2 个文件 No issues found；格式检查 2 files / 0 changed。
- [共享视频测试回归](video-platform-regression.log)：14 PASS。FakeVideoPlayerPlatform 增加可选按 DataSource 选择初始化结果，原默认行为保留；避免把媒体错误误注入 Cozymate 的本地头像动画。
- [图像及 SHA-256](agent-resource-visual-review/sources.json)：91 张原始图片（68 窗口 + 23 长图），切为 103 个连续片段、12 张联系表逐项查看。最终复采后哈希核对一致。
- 长图包含 Cozymate 问候、用户消息、回复、资料卡、建议、输入区和固定导航；续购含全部四方案及弹窗底部，妈妈页包含专家入口。普通媒体查看器未检测到垂直 ScrollPosition 溢出，缩放后的图片裁切是当前交互状态，不伪造为文档长图。

[联系表 01](agent-resource-visual-review/sheet-01.png) · [联系表 02](agent-resource-visual-review/sheet-02.png) · [联系表 03](agent-resource-visual-review/sheet-03.png) · [联系表 04](agent-resource-visual-review/sheet-04.png) · [联系表 05](agent-resource-visual-review/sheet-05.png) · [联系表 06](agent-resource-visual-review/sheet-06.png) · [联系表 07](agent-resource-visual-review/sheet-07.png) · [联系表 08](agent-resource-visual-review/sheet-08.png) · [联系表 09](agent-resource-visual-review/sheet-09.png) · [联系表 10](agent-resource-visual-review/sheet-10.png) · [联系表 11](agent-resource-visual-review/sheet-11.png) · [联系表 12](agent-resource-visual-review/sheet-12.png)

## 明确保留的限制与后续验证

- 中文资料卡按钮在宿主 Widget 截图中显示方块；实际 Text 标签、点击命中和跳转可核验。agentResultButtonStyle 指定 Manrope，未显式设置中文 fallback；与先前 [Agent 业务动作报告](AGENT-WORKFLOWS.md)发现一致。未改成英文或后期绘字掩盖，Android/iOS 的真实字体表现仍需原生核对。
- 视频平台只提供状态与空纹理，不能据此验收真实画面、音频、缓冲、设备方向或原生全屏。全屏窗口按本轮实际布局保存，未声称已经旋转。
- [已有原生媒体资料](../native/media-manifest.json)证明独立查看器中的 PDF/视频能力；本轮补的是宿主完整来源链。原生 Agent → PDF 正文/视频帧的连续链尚需执行，不能把两份独立测试合并描述成一条原生端到端流程。
- `missing-resource` 状态已有组件截图，但当前卡片的稳定资产检查不会正常产生该页，深链参数缺失等外部来源需要单独审计。
- 动态返回时长图的渐变背景可保留分段色带，内容、控件和边界均真实采集；未修饰截图。

完整 UI / UX 盘点仍未完成。下一步优先补原生媒体来源链及字体、系统通知/麦克风授权层，再核验其它未遍历交互、条件入口与全体长图审核清单。


## 后续 Android 补证

此前列出的原生来源链及中文按钮边界已在 Android 模拟器补验：[18 状态原生连续链](NATIVE-RESOURCE-JOURNEYS.md)。原生中文按钮和真实视频帧正常；宿主旧截图不改写，iOS、音频输出与其它条件仍不作推断。
