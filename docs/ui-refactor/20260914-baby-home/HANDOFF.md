# 宝宝首页：妈妈页风格重构交付

宝宝首页已按 Figma 实现。入口仍是 `/baby`，统一了身份区、每日知识、今日状态、吃奶摘要、生长指标与曲线、睡眠监测预告、宝宝切换和保存反馈。记录编辑器仍沿用原业务入口，其独立重构列入下一阶段；本报告不表示整个 Goal 已完成。

## 设计与实现

- [Figma 普通首页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=326-1086) · [大字号首页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=326-1236)。[28 个画板](figma-nodes.json)包括状态、字号和曲线选择参考，不是 28 个页面。画板先于 Flutter 实现建立；[设计读取](figma-design-context-0.json)、[实时节点核对](figma-live-verification.json)、[导出指纹](figma-artifacts.json)保留证据。
- 复用 MomHomeTokens、MomHomeSurface、MomHomeSectionHeader 和 momSettingsTheme。奶油背景、22 圆角卡片、14 间距、NotoSansSCHome 字体及玫瑰色操作保持一致。普通状态卡等高；大字号改为纵向卡片，知识标题使用完整可用宽度，喂养说明放在数值下方。
- 曲线保留实际 WHO 数据、记录筛选与绘制计算。Figma 曲线展示布局与视觉关系，数值以 App 原计算为准；测量单位在实现中使用次级字号。缺少出生资料仍显示完善入口，不产生参考曲线。
- 知识卡和阅读浮层通过 `useMomStyle` 显式采用新设计；其他调用方默认外观保持兼容。来源链接、内容边界及 Cozymate 跳转保持原逻辑。浮层关闭采用带“关闭”无障碍标签的图标，固定标题和底部操作，中间内容可滚动。
- 宝宝选择、每个宝宝的数据范围、记录保存后的刷新、保存反馈和撤销均保留原处理。睡眠监测仍为即将开放，底部导航继续使用外层现有导航。

## 最终清单对应

本轮按 6 类页面状态执行，129 条来源是已有操作证据，不是额外设计任务。

| 页面状态 | Figma 状态 | 当前运行证据 |
| --- | --- | --- |
| 无宝宝 | no-profile | `baby-home-current-no-profile-*`，添加与关闭资料弹窗 |
| 有宝宝 | empty | `baby-home-current-empty-top-*`，未记录状态 |
| 有记录 | recorded | `recorded-top`、三个 `section-*`、`curve-*` 视口；数量和时长断言 |
| 加载 | loading | `baby-home-current-loading-*`，挂起请求期间显示载入中 |
| 局部错误 | error | `baby-home-current-error-*`，重试恢复且不把失败写成未记录 |
| 生长曲线切换 | recorded、growth-身长、growth-头围 | weight / length / headCircumference 三种选择及相应图表 |

宝宝切换涵盖列表、当前选择、取消后保持原宝宝以及切换后数据隔离；知识浮层涵盖完整滚动、来源与边界显示、关闭和问问 Cozymate；首页保存提示涵盖保存、未确认撤销、重试、已撤销及关闭。共享浮层其他宿主在全局最终对照中独立核对，宝宝记录页尚未据此标为交付。

## 验证

[新增回归](../../../test/modules/baby/baby_home_redesign_test.dart)先在旧首页因目标字体断言失败，再完成实现。[联合检查](joint-tests.log)为 19 个文件、182 项通过，覆盖宝宝首页、资料、原记录编辑器、记录仓库、日期、WHO 参考、保存撤销和原知识浮层。最后补足取消断言与图片解码等待后，[受影响的 30 项](final-affected-tests.log)通过；这 30 项包含在 182 项中，不重复计数。[静态分析](analyze.log)9 个文件无问题。

[60 张运行视口](app-artifacts.json)包含 36 张本轮针对性画面和 24 张更新后的既有基准，普通宽度 320／390／430 与窄屏大字号由相应测试覆盖。已查看顶部、各分区、曲线、底部和浮层滚动末端；未发现布局溢出或操作遮挡。`app-review-1.jpg` 至 `app-review-5.jpg`、`figma-review-1.jpg` 至 `figma-review-4.jpg`保存视觉复核；两个旧基准中尚未解码的图片已通过测试等待修正，最终原图以 app-artifacts.json 为准。运行视口使用真实 Flutter 组件与隔离仓库，不等于线上设备发布验收。

[源文件与行为核对](preservation-check.json)：734 个原始证据文件及最终 inventory manifest 均未改变；BabyHomeController 与本轮开始前逐字节相同；加载、记住宝宝、记录和历史回调忽略格式后相同，曲线记录筛选相同。[本轮实现差异](implementation.diff)相对 before/，避免把其他会话已有修改混入本轮成果。旧截图基准备份在 before-goldens/。

下一阶段：宝宝记录历史及共享记录编辑器；随后复核已有无效路由与无入口动作评估画面，并对最终有限页面／浮层状态完成全局交付对照。无需重新盘点、补采或扩展截图矩阵。
