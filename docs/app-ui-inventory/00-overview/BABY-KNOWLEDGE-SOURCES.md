# Baby 六类知识内容与来源打开状态

通过正式用户 App 的 More → Baby，使用隔离 HTTP 数据、固定时钟和生产选题逻辑，实际下拉刷新并点击六类知识卡、来源链接与关闭。未直接设置页面主题，也未调用按钮回调绕过触摸。

## 实际链路

- 无记录选出饥饱信号；喂养 90 ml、睡眠 1 小时、尿湿、体重 3.8 kg、发育观察分别经 Repository / codec 与生产选题规则显示对应文章。数据仅在内存 fixture 中变化，没有写入真实宝宝账号。
- 每类均打开全文、滚动至来源并点击。平台方法通道断言 URL 与当前文章一致，且 `useWebView == false`；宿主返回 true 只表示分发被接受，不表示真实网页加载。
- 饥饱来源额外覆盖平台返回 false、抛出 PlatformException、再次点击、关闭文章后的错误提示、响应未完成时关闭，以及关闭后才返回失败。最后一种不会产生失效页面的提示。每个字号共 9 次来源分发。
- 六类文章完成后返回 More；断言没有 `/runs` 写请求。提问至 Cozymate 的预填及返回已在 [前批报告](BABY-PROFILE-CONTROLS.md) 验证。

## 视觉发现

- 393 px / 1x 下六篇文章完整内容基本适配视口。320 px / 2x 下标题和正文显著增高，长图保留全部摘要、三条要点、来源、内容边界说明与固定提问按钮；按钮文字和箭头可分为两行，来源标签也会换行。
- **来源失败提示被当前文章弹窗遮住。** 测试能找到 Snackbar，但实际截图中正文仍挡住提示文字，部分边缘仅见黑色阴影；关闭文章后才在 Baby 首页看到“暂时无法打开来源链接”。这是实际产品层级问题，本批如实记录，不能将 finder 存在当作用户看见。
- 平台响应未完成时没有进度状态，来源按钮仍可点击；关闭后晚到的失败不再弹出提示。
- 大字首页的统计卡仍呈居中的窄列，知识标题占据较多首屏空间，底部英文导航换行。这些布局现状保留。
- 关闭文章后的提示条是固定浮层。首次长图曾把它重复拼入每段；采集器现在测量 SnackBar，正文中间避开其范围，最终底部保留一次。它自然遮挡的底部内容可对照 [无提示完整首页](../04-baby/baby-knowledge-source-feedingCues-home/README.md)，原交互视口也单独保留。

## 状态与前驱索引

| 实际触发 | 截图、长图与前驱 |
| --- | --- |
| Tap development knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-development-detail/README.md) |
| Pull to refresh with development data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-development-home/README.md) |
| Close development article → Baby home | [运行证据](../04-baby/baby-knowledge-source-development-return/README.md) |
| Tap CDC · 婴幼儿发育里程碑 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-development-source-dispatched/README.md) |
| Tap diaper knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-diaper-detail/README.md) |
| Pull to refresh with diaper data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-diaper-home/README.md) |
| Close diaper article → Baby home | [运行证据](../04-baby/baby-knowledge-source-diaper-return/README.md) |
| Tap AAP HealthyChildren · 婴儿便便颜色 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-diaper-source-dispatched/README.md) |
| Tap feeding knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-feeding-detail/README.md) |
| Pull to refresh with feeding data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-feeding-home/README.md) |
| Close feeding article → Baby home | [运行证据](../04-baby/baby-knowledge-source-feeding-return/README.md) |
| Tap CDC · 婴幼儿营养 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-feeding-source-dispatched/README.md) |
| Tap feedingCues knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-feedingCues-detail/README.md) |
| Pull to refresh with feedingCues data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-feedingCues-home/README.md) |
| Tap CDC · 饥饿与饱足信号 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-feedingCues-source-dispatched/README.md) |
| Tap growth knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-growth-detail/README.md) |
| Pull to refresh with growth data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-growth-home/README.md) |
| Close growth article → Baby home | [运行证据](../04-baby/baby-knowledge-source-growth-return/README.md) |
| Tap WHO · 儿童生长标准 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-growth-source-dispatched/README.md) |
| Baby → More after all six knowledge topics | [运行证据](../04-baby/baby-knowledge-source-more-return/README.md) |
| Tap sleep knowledge card → complete article | [运行证据](../04-baby/baby-knowledge-source-sleep-detail/README.md) |
| Pull to refresh with sleep data → production-selected knowledge card | [运行证据](../04-baby/baby-knowledge-source-sleep-home/README.md) |
| Close sleep article → Baby home | [运行证据](../04-baby/baby-knowledge-source-sleep-return/README.md) |
| Tap CDC · 婴儿安全睡眠 → platform accepts external URL; host does not render browser | [运行证据](../04-baby/baby-knowledge-source-sleep-source-dispatched/README.md) |
| Close article while Snackbar remains → Baby home | [运行证据](../04-baby/baby-knowledge-source-source-error-dialog-closed/README.md) |
| PlatformException → same error feedback; article remains | [运行证据](../04-baby/baby-knowledge-source-source-exception-error/README.md) |
| External launcher returns false → source error Snackbar | [运行证据](../04-baby/baby-knowledge-source-source-false-error/README.md) |
| Late failure after dialog disposal → no stale Snackbar | [运行证据](../04-baby/baby-knowledge-source-source-late-failure/README.md) |
| External dispatch response pending → article remains interactive | [运行证据](../04-baby/baby-knowledge-source-source-pending/README.md) |
| Close article before launcher resolves → Baby home | [运行证据](../04-baby/baby-knowledge-source-source-pending-closed/README.md) |

## Android 来源链

[真实 Android 8 步](../native/knowledge-source/README.md)：当前 App 的生长知识卡 → WHO 来源 → Chrome 实际加载 → 关闭浏览器通知引导 → 系统返回同一篇文章 → 关闭 → Baby → Me/Mia。PNG、UI XML、坐标点击、原始操作时间和哈希全部保留，文章/Baby/Mia 返回前后的 XML 一致。未开启 Chrome 通知。

此证据是 Android 模拟器上的真实平台跳转，不是实体手机。其它来源的网络页面未在设备逐一打开；外部网站落地视口不冒充用户 App 的完整长页面。

## 验证与采集范围

30 个逻辑状态、60 个视口变体、43 张长图，14 个状态使用长图为主图。103 张宿主原图分为 291 个连续全宽片段、140 个唯一片段；124 个新片段组成 21 页，全部审阅，16 个与先前已审阅片段逐像素一致。修复重复提示条后重新审阅改变的第 18–21 页，其他页 SHA 保持一致。见 [分段来源](baby-knowledge-source-visual-review/sources.json) 与 [证据审计](baby-knowledge-source-evidence-audit.json)。

- [最终严格采集](runs/20260913T212757-targeted/capture.log)：2 项通过，不更新 Golden 基线；同目录命令与退出码留存。
- [全仓静态检查](baby-knowledge-source-analyze.log)：No issues found。新增测试的 4 条 lint 已修正。
- 初始失败是文章关闭后首页位置未归顶、下拉没有刷新；测试改为实际拖回顶部，并断言读取请求增加。记录类型沿用生产 codec 的 formula。
- 采集器新增 SnackBar 固定浮层测量，根弹窗上方仍以弹窗为前景，避免将背景 Snackbar 当作文章正文控件。两张关闭后长图分别测得 63 / 125 px 高的提示条，正文避让包含额外 8 px 阴影。

其它历史长图中的 6 张 Snackbar 候选随后已全部重采和审阅，没有重复；三个测试文件 30 项通过，涉及 249 张 PNG 保持一致，见 [固定提示条复核](SNACKBAR-LONG-REVIEW.md)。全局 UI 盘点、其它 Baby 控件分支和历史图像审核仍未完成，见 [Baby 控件清单](BABY-CONTROL-COVERAGE.md)、[完成审计](AUDIT.md)。
