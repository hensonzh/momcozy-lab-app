# 首次使用：资料填写与加载状态

本轮完成已有 [6 个源截图状态](source-inventory.json) 对应的姓名年龄、分娩日期、分娩方式与宝宝数量，以及加载和保存失败界面。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=230-1108) 设计 [17 个画板](figma-nodes.json)，再改 Flutter。数字形象创建、照片来源、生成等待与候选选择仍是后续重构范围，本轮没有将整个 onboarding 标为完成。

资料填写现在由固定的步骤进度、说明卡和填写卡组成。标题使用妈妈页的 24 号字，说明采用 13 号正文；奶油背景、柔和渐变、玫瑰色操作和 22 圆角复用 MomHomeTokens 与 MomSettingsCard。字段标签位于输入框外，可随字号换行，尤其是分娩方式和宝宝数量；错误采用共用 AuthNotice。三步字段、错误与按钮共用滚动区域，保留键盘拖动收起、返回上一页和回到顶部的行为。

姓名年龄、分娩日期和分娩方式的用途与文案保持原意。年龄仍校验 12–70，分娩方式仍可不填，宝宝数量仍为 1–6。日期选择沿用原 Material 控件、两年前年份起至今天的范围及大字号输入模式，仅注入同一局部主题；参考此前日程中的日期输入设计。保存仍调用原控制器，失败保留草稿，忙碌时禁止重复提交和返回。资料完成后仍进入原数字形象流程。

验证：

- [13 项专项检查](design-tests.log)及[基线比对](verified-tests.log)：320/390/430 屏宽、1×/2× 字号，姓名与年龄校验、键盘占用、日期取消和选定、返回保留草稿、方式选择、保存失败重试、加载失败重试。
- 新增 320×568、2× 字号、键盘占用 200 的完整路径；选择剖宫产和 6 个宝宝，检查保存期间只发起一次请求、返回与按钮锁定，失败后再次提交的完整请求体与首次一致。保留原字段编辑行为，没有增加原来不存在的禁用条件。
- [41 项行为回归通过](behavior-tests.log)：资料接口、控制器、路由、能力开关、发布重置、数字形象任务控制器、生成后的进入提示和共享日期时间选择器。[两个文件静态分析通过](analyze.log)。
- [8 项源码行为对比一致](behavior-checks.json)：资料导航、姓名年龄校验与草稿、日期必填、保存与确认、日期范围和选定结果，以及数字形象上传、选择、导航、候选图片及生成状态逻辑。

已目视核对 [Figma 分娩信息](figma/birth.png)、[大字号](figma/large.png)、[保存状态](figma/short-busy.png)，以及 Flutter [基本资料](verified/onboarding-basics-390.png)、[大字号资料](verified/onboarding-basics-320-2x.png)、[分娩信息](verified/onboarding-birth-320-2x.png)、[短屏保存](verified/onboarding-short-busy-320-2x.png)、[保存失败](verified/onboarding-short-error-320-2x.png) 和 [日期输入](verified/onboarding-short-date-input-320-2x.png)。长页面截图保留真实滚动位置；单行输入框保持水平输入行为。系统日期选择器标题的省略形式由原 Material 控件决定。

`MOMCOZY_ENABLE_ONBOARDING` 默认仍关闭，本轮没有开启能力或改变生产入口。原截图主要为组件场景；另通过实际 App 路由测试验证启用引导时的资料流程和进入后续页面。未运行原生设备重新采集、构建、发布或 Session A 的清单生成测试。

[清单](inventory-delta.json)仍为 2675 个状态，无增量。[源图及元数据指纹](source-image-hashes.json)、[实现指纹](implementation-hashes.json)和修改前源码已保存。整体任务保持 active；下一步基于已有数字形象相关截图继续 Figma 设计。
