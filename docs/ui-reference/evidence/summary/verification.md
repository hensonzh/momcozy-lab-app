# 咨询总结与行动反馈

2026-09-12。用户 App 范围，专家工作台文档页没有修改。

## 参考

重新读取 UserApp.tsx SummaryPage 3810–3864 行及 styles.css 901–952 行，捕获 `services/summary-viewport.png`、`summary-full.png` 和 `summary-pending-viewport.png`。完整图展开 user-content 内部滚动容器并打开信息区；初次 fullPage 截图只截到内部滚动区，已重新捕获并目视确认从标题到元数据全部可见。capture-manifest.json 保留来源和捕获方式。

设计浏览器采用隔离的已完成预约与中性测试建议，所有 API / 外部请求被阻断。它是当前设计的真实 DOM 渲染，不代表后端发布或临床内容。浏览器 mock 使用采集诉求作标题，原生与设计 server 分支一致，使用实际已发布 plan.title。

## 结构与对应实现

原生总结改成紧凑返回标题栏，18 间距串联暖色总结卡、主行动卡、编号后续行动、带勾选标记的观察目标、绿色帮助区和可展开的服务信息。总结正文为主视觉，发布人及确认日期置底部分隔线后；行动说明、时限和条目保持真实顺序。主行动继续优先选择待完成／进行中任务，没有可执行项时保持原有回退策略。

内容提取到 ConsultationSummaryContent，异步加载、15 秒等待发布刷新、错误处理及任务提交继续由现有 CareSummaryController 负责。新增色值集中于 Design System。头像采用真实发布人姓名缩写，空姓名也不会触发 characters.first 异常。原生数据没有服务包展示名，所以信息区保留实际咨询时间、服务截止、剩余次数、发布确认时间及服务进度入口，不把 packageId 或示例名称作为产品文案。

“查看完整行动计划”连接原生日程 `/schedule`，返回后刷新总结；“查看怎么做”和后续行动保留已有任务详情与反馈能力。设计工程没有这个原生任务反馈弹窗，单独登记为用户批准的衍生设计。弹窗使用共享标题／关闭、滚动说明、分类时限、真实日期与四项进度 Chip，原有状态 API、publication/sourceKey/expectedVersion 均保留。

## 行为与视觉证据

新增 9 项测试覆盖 320/390/430 宽度与 1x/2x 字号，已发布正文、两个行动入口、完整计划回调、展开元数据、服务进度回调、整理中、未完成咨询无总结、读取失败与恢复。加载中的请求完成后显示整理中，15 秒刷新可切换到已发布内容。既有工作台文档测试中的用户总结基线同步更新，工作台截图未变化。

任务打开不自动提交；明确选择后才写入。提交中禁止硬件返回和重复选择；网络不确定时锁定其它状态，重试保留同一 publication、sourceKey、version 和目标状态。plan_superseded 冲突必须先载入新方案，后续提交使用新的 publication 与版本。成功反馈的选中态由响应更新。

实际 Flutter 截图为 `test/goldens/design_system/summary-{published,task,metadata,pending,empty,offline,loading,uncertain}-*.png`。标准宽度正文、任务、展开信息、整理中和 320 大字号已逐张查看。大字号的标题、内容和 Chip 换行，元数据转为单列，长正文与底部操作可滚动。所有业务说明均来自既有用户文案或已发布字段，不读取工作台临床笔记。

整合服务、咨询、通知、文档控制器／页面和路由契约的回归结果见 regression.log，静态分析见 analyze.log。本地普通 APK 构建、安装和 Mia 冷启动记录见 build.json / build.log / native-restored-home。

后端本地环境缺少可查询的已发布咨询，正文、反馈与等待发布通过受控仓储验证；没有向真实专家发布内容或修改真实计划，不能描述成临床服务发布端到端通过。
