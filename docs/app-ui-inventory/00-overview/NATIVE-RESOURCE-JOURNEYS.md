# Cozymate 资料卡的 Android 原生连续链

在 Android 模拟器执行正式 App 路由：More → Cozymate → 输入并发送问题 → SSE 资料卡 → PDF / 视频 / 图片 / 续购 → 返回原资料卡。新增 **18 个原生状态窗口、7 张独立纵向长图**；PDF 第一页/第二页/复位共享适配宽度长图，因此总索引中有 9 个长图条目。测试步骤耗时 38 秒，1 项完整链通过。

## 运行边界

- 正式 MomCozyFlutterApp、createMomCozyRouter、AgentHubPage、SSE parser/runner、artifact mapper/dispatcher、ProductAssetRepository 与媒体 UI 均运行。通过公开 agentHubBuilder 注入隔离 SSE、业务传输和会话；没有直接挂载目标查看器替代点击。
- 资产通过模拟器内部 loopback HTTP 提供：实际两页 PDF、已有 Cozymate MP4、已有泌乳 PNG。PDFium、Android 视频解码器、Image 解码和系统字体均为真实实现；没有注入字体或空视频纹理。
- 媒体请求鉴权头经断言验证；只有一个 SSE 请求，往返不重复发送。业务数据、服务价格、身份均为测试数据；未对真实账号写记录、购买或请求模型。
- 物理视口 1280 × 2856，DPR 3，系统字号 1.0。截图来自 integration binding 的实际 Flutter surface，保留系统安全区但不包含 Android 状态栏文字；恢复验证截图另用 adb 采集。

## 已观察结果

1. 原生资料卡四个中文按钮均可读。此前宿主金图中的方块未在这台 Android 模拟器复现；不据此推断 iOS 字体表现。
2. PDF 的两页、下一页、放大、缩小、上一页和返回实际执行。正常宽度长图包含两页完整内容；放大态纵向走到底，横向仍为放大后的当前视窗，文字左缘裁切如实保留，不能称为放大文档的全宽图。
3. 视频真实画面可见；播放后 position > 0，暂停、进度定位、静音和沉浸式全屏/退出均执行。视频为纵向 4 秒的现有头像素材，因此全屏仍为竖向画面；不宣称旋转验收或声音输出已验证。
4. PNG 正常解码，双击矩阵为 2.5x，返回恢复资料卡。图像黑边及放大裁切为实际布局。
5. 续购展示隔离目录中的一个禁购方案；返回先落到 Me，再点击 Cozymate 恢复同一回复。购买链的其它状态见宿主续购报告。

## 状态、触发与前驱

| 状态 | 实际触发 | 页面证据 |
| --- | --- | --- |
| 原生资料卡与中文按钮 | Actual native Agent reply with four Chinese action labels | [窗口、长图及前驱](../05-agent/native-resource-card/README.md) |
| 原生 PDF 第一页 | Tap PDF action → native PDFium displays first of two pages | [窗口、长图及前驱](../11-media/native-resource-pdf-first/README.md) |
| 原生 PDF 第二页 | Tap next page → page two | [窗口、长图及前驱](../11-media/native-resource-pdf-next/README.md) |
| 原生 PDF 放大 | Zoom PDF → actual rendered zoom and complete document | [窗口、长图及前驱](../11-media/native-resource-pdf-zoom/README.md) |
| 原生 PDF 缩小复位 | Zoom out then previous page → original document view | [窗口、长图及前驱](../11-media/native-resource-pdf-reset/README.md) |
| PDF 返回原资料卡 | Native PDF back → original Agent card | [窗口、长图及前驱](../05-agent/native-resource-pdf-return/README.md) |
| 原生视频就绪 | Tap video action → real Android decoder renders asset | [窗口、长图及前驱](../11-media/native-resource-video-ready/README.md) |
| 原生视频播放 | Play → native video position advances | [窗口、长图及前驱](../11-media/native-resource-video-playing/README.md) |
| 原生视频暂停 | Pause native playback | [窗口、长图及前驱](../11-media/native-resource-video-paused/README.md) |
| 原生视频定位并静音 | Seek and mute → actual controller controls | [窗口、长图及前驱](../11-media/native-resource-video-seek-mute/README.md) |
| 原生视频全屏 | Open native immersive player | [窗口、长图及前驱](../11-media/native-resource-video-fullscreen/README.md) |
| 退出全屏恢复内嵌视频 | Exit immersive player retains paused position | [窗口、长图及前驱](../11-media/native-resource-video-inline/README.md) |
| 视频返回原资料卡 | Video back disposes player and restores original card | [窗口、长图及前驱](../05-agent/native-resource-video-return/README.md) |
| 原生图片查看 | Image card → native decoded PNG | [窗口、长图及前驱](../11-media/native-resource-image/README.md) |
| 原生图片双击放大 | Double tap → 2.5x image zoom | [窗口、长图及前驱](../11-media/native-resource-image-zoom/README.md) |
| 图片返回原资料卡 | Image back → original native card | [窗口、长图及前驱](../05-agent/native-resource-image-return/README.md) |
| 原生资料卡进入续购 | Native artifact internal link → generic renewal route | [窗口、长图及前驱](../08-expert-service/native-resource-renew/README.md) |
| 续购返回并恢复原资料卡 | Renewal back → Me; Cozymate tab restores the original reply | [窗口、长图及前驱](../05-agent/native-resource-renew-return/README.md) |

## 截图和长图检查

25 张原始 PNG（18 窗口 + 7 长图）分为 51 个连续片段，13 张联系表已逐一查看。长图使用真实 ScrollPosition 或 PDF visibleRect 实测拼接，页头、固定底栏保留一次；聊天长图包含问候、问题、回复、四个入口、建议和输入区。缩放 PDF 的横向限制见上文。截图没有后期补字或重绘。

- [原始运行路径](../native/resource-journey/native-resource-journeys.json)
- [路径、资源哈希及来源代码哈希](../native/resource-manifest.json)
- [图片检查与哈希](native-resource-visual-review/sources.json)

[联系表 01](native-resource-visual-review/sheet-01.png) · [联系表 02](native-resource-visual-review/sheet-02.png) · [联系表 03](native-resource-visual-review/sheet-03.png) · [联系表 04](native-resource-visual-review/sheet-04.png) · [联系表 05](native-resource-visual-review/sheet-05.png) · [联系表 06](native-resource-visual-review/sheet-06.png) · [联系表 07](native-resource-visual-review/sheet-07.png) · [联系表 08](native-resource-visual-review/sheet-08.png) · [联系表 09](native-resource-visual-review/sheet-09.png) · [联系表 10](native-resource-visual-review/sheet-10.png) · [联系表 11](native-resource-visual-review/sheet-11.png) · [联系表 12](native-resource-visual-review/sheet-12.png) · [联系表 13](native-resource-visual-review/sheet-13.png)

## 构建、测试与恢复

- 初次构建默认 Maven AAPT2 9.0.1 独立运行 version / daemon 均超时，见 [初始失败](native-resource.log)。SDK 36.0.0 的 AAPT2 version / daemon 均退出 0。使用仓库 scripts/run-flutter-invite-dev.mjs 已有的 ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride 配置重试，没有更改项目 Gradle 配置或升级依赖。该覆盖选项也见 [Android 官方源码](https://android.googlesource.com/platform/tools/base/+/studio-master-dev/build-system/gradle-core/src/main/java/com/android/build/gradle/options/StringOption.kt)。
- 首次可运行测试在输入后未等待发送控件刷新，断言 SSE 请求数为 0；[失败日志](native-resource-aapt2.log)保留。采集测试增加输入后的 pumpAndSettle、有限请求等待，并使用 broadcast 测试流避免未订阅关闭挂起；正式 App 未改动。
- [最终通过日志](native-resource-run2.log)：构建 15.4 秒，安装约 470ms，完整链测试 38 秒，1 PASS。
- [命令及临时构建配置](native-resource-command-aapt2.json)、[设备内断言结果](../native/resource-journey/native-resource-result.json)。
- [测试静态检查](native-resource-analyze.log)与[全仓静态检查](native-resource-full-analyze.log)：均为 No issues found；Dart 格式检查 1 file / 0 changed。
- 原包通过 adb install -r 恢复，安装包 SHA-256 与备份一致，未卸载或清空数据。首次使用了错误 Activity 名称，随后通过系统 resolve-activity 查询实际组件并成功冷启动。Mia 仍处于登录状态并回到妈妈首页；[恢复元数据](../native/resource-journey/restore.json)、[恢复截图](../native/resource-journey/restored-home.png)、[UI 层级](../native/resource-journey/restored-home.xml)。

## 总目标仍待验证

这批证据补上了原生资料卡到媒体正文的连续链，并核实本机中文按钮。系统通知/麦克风授权、其它条件入口和未遍历交互、全体长图人工审核仍需继续，iOS 与实体设备未在本轮运行。总索引完整性 PASS 只验证文件、哈希、链接和滚动范围，不证明全部 UI / UX 覆盖完成。
