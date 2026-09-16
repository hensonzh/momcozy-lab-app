# 已完成页面的增量状态复核

复核 [198 个新增或更新的截图状态](source-inventory.json)，确认可复用现有妈妈页设计体系。这些是既有页面的状态补充，没有新增完成页面，累计仍为 33 个已实现并经组件验证的范围。未列入进度表的宝宝、个人资料等页面继续待处理。

已逐组阅读 17 张来源联系表，核对登录与引导、泌乳、AI 会话、日程、More、预约与咨询、信息采集、续购和视频。来源均未标记 `needs_long_review`，长备注、列表末尾、短屏与大字号仍按各自视口检查。[逐条覆盖记录](coverage.json) 将每个状态映射到已有交付报告及 Figma 状态族；这是状态族复用，不声称每一条原始旅程都在本轮重新执行。

实际调用 Figma 检查了 [143 个对应画板](figma-live-nodes.json)，均存在。另读取 [聊天字体、头像、资料入口和咨询状态](figma-inspection.json) 的当前设计属性。未重复创建或改动已稳定的设计。代表入口：[聊天阅读](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=271-1086)、[日程](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=214-1108)、[泌乳](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=296-1086)、[视频](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=291-1334)。

验证发现并修正了 4 张过期的聊天测试基线：

- Markdown 320 普通字号的旧基线没有加载头像；现有测试场景已经等待图片解码，当前头像与既有设计和其余尺寸一致。
- 三个宽度的 transcript 旧基线仍使用较早的强调文字字体及灰色列表标记。当前实现已采用此前聊天阅读重构确认的 NotoSansSCHome 粗体和正文色标记。

已检查实际差异、Figma、当前实现和此前阅读设计报告，仅接受这 4 张当前渲染图；没有修改生产代码或业务逻辑，没有屏蔽差异或放宽断言。[基线变更记录](baseline-updates.json) 包含前后指纹、差异范围和理由；`baseline-review/` 保存前后图片。

本轮 [324 项检查](tests.log) 首次为 320 项通过、4 项上述基线差异。同步基线后，仅重跑受影响的两个测试文件，[24 项全部通过](chat-final-tests.log)，不与前面的 324 项重复相加。最终这 324 项均有当前通过结果。测试命令见 [test-command.json](test-command.json)；未运行文件名含 inventory 的清单测试，移除了当前测试进程的 `MOMCOZY_UI_INVENTORY_DIR` 环境变量，最终比较未开启基线更新。没有代码改动，因此没有重复执行静态分析。

来源文件与元数据保持只读；归档核对 [1210 个指纹](source-image-hashes.json) 一致。详见 [完成记录](completion-record.json) 与 [清单增量](inventory-delta.json)。原生日期控件沿用平台行为；视频画布来自受控平台夹具，不能据此声称完成真实视频解码或真机验收。未构建、发布或重新采集原生截图。

下一步处理已有截图中的宝宝资料编辑器，再推进宝宝首页、记录及其他未重构范围。增量队列归零也不代表所有页面完成；Goal 保持 active。
