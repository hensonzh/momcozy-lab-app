# 数字形象创建、生成与选择

本轮完成已有 [15 个源截图状态](source-inventory.json) 对应的数字形象创建、照片来源和默认形象确认、上传错误、生成等待、候选选择、启用结果及应用内任务提示。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=234-1108) 设计 [30 个画板](figma-nodes.json)，再落实 Flutter，保留现有母婴形象资产。与此前 [资料填写](../20260914-onboarding-profile/HANDOFF.md) 一起覆盖当前清单中的首次引导页面；整体 App 重构仍在进行。

创建页以浅紫渐变说明卡和操作卡构成：示例形象缩为 72×108，大字号为 64×96，上传按钮与完整照片用途说明放在一起。生成页先展示真实当前阶段，再解释生成过程和后台等待。资料步骤与形象步骤共用进度头；从 App 返回形象任务时保留原返回入口。候选继续展示服务器返回的四张图，选择边框和勾选状态保持明确；原形象说明使用整卡宽度，避免大字号把长单词拆成零碎窄行。

照片来源弹层复用局部主题。默认形象确认与后台生成提示采用 MomSettingsFlowDialog，标题固定，内容与按钮可滚动；原来的遮罩、返回和选择结果规则保持。启用完成使用薄荷色成功提示。任务 Banner 使用共享圆角和字体，将排队/生成中、可选择、失败、完成状态分别呈现在表面、薄荷和浅琥珀色卡片中，继续保留原点击条件、无障碍提示、触觉反馈和过渡动画。

验证：

- [56 项设计与阅读检查通过](design-tests.log)：320/390/430 屏宽、1×/2× 字号，完整资料步骤和形象流程；状态截图包含照片失败、来源选择、默认确认、候选选择、等待、启用与任务提示。较长正文保持 1.55 行高。
- 新增 320×568、2× 字号下缩略图失败后重试、图片就绪后选择、确认期间禁用候选/重复提交/换照片、失败保留选择，再次提交成功的检查。实际请求仍发送原候选 ID 和 `use_default_avatar: false`。
- [97 项联测全部通过](joint-tests.log)：上述视觉基线与行为检查，加资料/形象接口、控制器、路由、能力开关、发布重置、生成后的进入提示和日期时间组件。[3 个文件静态分析通过](analyze.log)。
- [13 项行为对比通过](behavior-checks.json)：资料步骤和提交、形象状态优先级、照片验证与上传、来源返回值、默认确认、后台生成遮罩与返回、确认/启用/回跳、候选可用性与缩略图重试版本，以及任务提示的状态文案、点击条件、监听与无障碍语义。对比忽略格式化空白和尾逗号。

已目视核对 [Figma 创建页](figma/choice.png)、[候选](figma/review.png)、[生成进度](figma/generating.png)、[大字号确认](figma/default-confirm.png)、[任务提示](figma/banners.png)，以及 Flutter [创建页](verified/onboarding-required-390.png)、[大字号原形象选择](verified/onboarding-review-footer-320-2x.png)、[确认弹层](verified/onboarding-default-confirm-320-2x.png)、[短屏确认中](verified/onboarding-avatar-short-confirm-busy-320-2x.png)、[图片失败](verified/onboarding-avatar-short-image-error-320-2x.png)和[生成等待正文](verified/onboarding-reading-generation-wait-320-2x.png)。候选图在受控测试和 Figma 中复用原形象作为样例；生产 UI 继续加载真实候选文件。部分基线保留实际滚动位置，底部操作可以滚动到达。

复核修正了窄屏说明图容器小于四个图标所需高度造成的 2 像素溢出，以及弹层未继承页面局部主题的问题。没有改变原图片授权、上传、生成、删除和候选提交业务，没有新增能力开关或打开默认关闭的首次引导功能；未调用真实云端形象生成。

[清单检查](inventory-delta.json)仍为 2675 个状态，无增量；[源图及元数据指纹](source-image-hashes.json)、[实现指纹](implementation-hashes.json)和修改前副本已保存。此前资料步骤的旧实现指纹对应当时版本；本报告记录包含本轮修改的当前文件版本。未写入 Session A 清单、未重新采集原生截图、未构建或发布。下一步核对未覆盖页面与现有待核对目的状态，继续按截图推进，不能将这些局部交付视为整个 App 完成。
