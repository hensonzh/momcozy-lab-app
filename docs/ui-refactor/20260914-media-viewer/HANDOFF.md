# 图片查看器与媒体反馈

完成 [36 个已有截图状态](source-inventory.json) 对应的图片查看器、附件全屏图片，以及媒体加载、失败、不可用和缺少资源提示。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=265-1086) 完成 [30 个普通／大字号画板](figma-nodes.json)，再落实到 Flutter。图片使用项目原有 milk-hero 资产作为测试内容，Figma 资产节点为 263:1086，没有替换用户图片。

图片保留深色画布；返回栏采用妈妈页的奶油背景、玫瑰色返回按钮和 NotoSansSCHome。长标题最多两行，保留完整文本的 Tooltip 与语义标签；返回按钮为 44×44。加载与错误提示复用 MomSettingsCard、共享字体、边框与圆角，失败时提供明确的“重新加载”按钮。无重试能力时不显示按钮。PDF 和缺少资源提示使用浅色背景；大字号内容可滚动，避免短屏裁切。

本轮同时修复重试立即失败时的未处理异常。图片和 PDF 在点击重试时创建新 Future，但 FutureBuilder 到下一帧才订阅；立即失败可能落在这个间隔内。现在为该 Future 立即注册错误监听，FutureBuilder 仍收到同一个错误并显示原失败状态。没有改变请求、认证、缓存、重试次数或错误类型。

验证结果：

- 修改前 [48 项媒体／图片测试通过](before-tests.log)。新版布局与旧截图基线的差异见 [首次检查](design-before-goldens.log)，代表差异已与 Figma 目视核对后更新基线。
- [立即重试回归修复前](immediate-retry-red.log) 图片和 PDF 均复现 ProductAssetLoadException；修复后 [51 项设计检查通过](update-goldens.log)。新增短屏测试验证完整标题提示、44 触控区、重试按钮可达、再次失败仍可显示，以及返回首页。
- 图片原有双击放大与复位检查增加了实际拖动和缩放／拖动／复位截图；[6 个尺寸组合通过](zoom-goldens.log)。覆盖 320/390/430 宽度与 1×/2× 字号，短屏为 320×568 / 2×。
- 最终 [103 项联测通过](joint-tests.log)，不启用更新基线。覆盖媒体内容与 API 仓库、图片加载和重试、视频组件、附件设计、图片预览、语音媒体基础行为、通知会话路由和底部导航。
- [5 个修改文件静态分析通过](analyze-final.log)，四项 [行为对比通过](behavior-checks.json)。除明确记录的 Future 错误监听修复外，图片资源加载与缓存、附件全屏实现、媒体路由、PDF 翻页、图片手势和视频配置保持不变。
- 保存 [105 张当前组件验证图](verified-images.json)。已目视检查普通加载、图片放大与拖动、附件原图和不可用提示，以及短屏大字号图片失败、PDF 失败和缺少资源状态；Figma 代表图见 [大字号图片失败](figma/large-image-error.png)、[大字号附件不可用](figma/large-attachment-unavailable.png) 和 [缺少资源](figma/large-missing.png)。

本轮范围是图片查看器及共享反馈。已加载 PDF 的文档工具栏、完整视频播放器、整个上传旅程及复杂聊天内容仍需单独设计与验收。返回后的聊天页和图片元数据复用已完成设计，逐状态边界见 [覆盖记录](coverage.json)。现有 Android 截图只用作设计输入，本轮没有运行原生截图、构建或发布，也没有运行 Session A 的清单写入测试。

修改四个生产文件和一个测试文件，保存 [实现指纹](implementation-hashes.json)、[311 个源截图及元数据文件指纹](source-image-hashes.json) 和修改前文件。收尾清单为 2737 个状态；本轮观察到 2 个新增、13 个变化，已入队，见 [增量记录](inventory-delta.json)。当前待核对增量 86 个，这不是全 App 的剩余页面数量。继续处理已有截图中的附件其余提示、语音提示、复杂 Markdown、表单／行动／结果卡片，以及 PDF／视频余下状态；goal 保持 active。
