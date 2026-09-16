# 日程、行动计划与个人安排

“查看完整行动计划”在现有路由中进入 `/schedule`。本轮按真实日程页处理，完成 [93 个源截图条目](source-inventory.json) 对应的月历、当天安排、照护方案和个人日程编辑界面。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=214-1108) 设计并检查 [40 个画板](figma-nodes.json)，再落实 Flutter；画板覆盖页面、任务和预约状态、编辑与保存恢复、删除、日期时间选择、草稿放弃与菜单。

月历、当天安排和当前照护方案现在有明确分区。月历以薄荷色显示服务期，保留月份切换、今天定位、安排标记和服务筛选。当天安排采用统一卡片：时间与状态在上方，标题和正文使用完整宽度，操作保持原用途。照护方案展示完成进度与真实发布人，原摘要和服务计划入口保留。大字号月份标题使用完整宽度；添加按钮有独立底部区域，不再遮挡列表操作。底部主导航仍由现有 App Shell 提供。

编辑与删除复用 MomSettingsFlowDialog、MomSettingsCard 和妈妈页设计令牌，标题与关闭操作固定，字段、错误与提交操作可滚动。日期与时间继续使用原系统选择器，保留范围、输入模式和本地化校验，继承局部主题；时段选中态使用薄荷色。保存忙碌与结果不确定时仍锁定字段，不确定创建仍使用原幂等键重试。删除确认默认保留操作突出，确认删除单列展示。

验证结果：

- [专项](design-tests.log) **32 项通过**：320/390/430 宽度、1×/2× 字号，任务版本更新、跳过与恢复、服务期筛选、预约和计划跳转、个人日程增改删、未保存草稿保留、同一创建重试、保存期间锁定与返回保护。
- 新增覆盖 320×568 短屏、键盘占用、首次加载和离线重试、刷新失败保留安排、任务提交期间禁止竞争更改、100 条已加载日程滚动到末条，以及日期越界和无效时间校正后保存真实值。
- [联测](joint-tests.log) **77 项通过**，涵盖日程、日程控制器、咨询总结、服务进度及共用日期时间和错误组件。[静态分析](analyze.log) 四个文件无问题。
- [行为对比](behavior-checks.json) 11 项均一致，包括控制器、日期与服务期计算、当天数据过滤顺序、任务动作、编辑保存与幂等键、脏状态、放弃确认与错误含义。主题参数和布局调整不改变原业务流程。

视觉核对包括 [Figma 日程](figma/schedule.png)、[大字号](figma/large.png)、[编辑](figma/editor.png)、[日期选择](figma/date-picker.png)，以及 [Flutter 日程](verified/schedule-overview-390-1x.png)、[大字号](verified/schedule-overview-320-2x.png)、[方案展开](verified/schedule-plan-390.png)、[编辑](verified/schedule-create-390.png)、[删除确认](verified/schedule-delete-390.png)、[短屏刷新错误](verified/schedule-short-refresh-error.png)、[长列表末尾](verified/schedule-long-agenda-end.png) 和 [时间校验](verified/schedule-time-error-320-2x-short.png)。部分基线保留实际测试滚动位置。系统选择器的语言、日期排布和控件结构由原 Material 组件及运行时 locale 决定。

日程模块另有 [11 个目的页截图](destination-review.json)，实际跳转至已经重构的服务进度、咨询准备、信息采集或咨询总结，沿用对应设计。本轮没有改写 Session A 清单或运行清单生成测试，未构建、发布或重新采集原生 App。当前仍观察到 2675 个截图状态，无增量；[源图指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json) 已保存。

现有接口每次读取前 100 条、页面没有继续加载按钮的行为保持原样；源截图中第 101 条未加载的问题未作为视觉重构的一部分改变。整体任务保持 active，下一步按现有认证与登录截图继续。
