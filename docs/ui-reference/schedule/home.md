# 日程月历与当日安排

- ID：`schedule/home`
- 类型：page
- 参考来源：original
- 设计源码：[PlanPage](../source/src/pages/UserApp.tsx#L3042)，第 3042–3262 行
- Flutter：`lib/modules/schedule/presentation/schedule_page.dart`
- Route / 入口：`/schedule`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../schedule/reference/home.png)

原始路径：`me-agent-style-sync/diary-followup/15-navigation-schedule.png`；SHA-256：`f2b38b68b08a21a1ab00f4d851b25c21c57061c3fd8092a088b211cec5564b0e`。

[查看参考图](../schedule/home-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`731cccedabe3bdb51da966e547be96cca6354ad2cf3138c8e974d36ff52f73ff`。

[查看参考图](../schedule/home-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`58c5916482b875aa5f5c85302924b0197a54b4ab8d9500ad02b51844b7f38a53`。


复核记录：月历、真实服务期筛选、平铺日程、预约/任务状态标签和已发布照护方案的展开摘要/计数/进度已按当前参考对齐。照护方案入口复用既有 episode 计划页，文案据实际目标调整；没有虚构周期总结路由。三宽、2x 字号、月切换、预约及方案回调通过；本地 APK 核对空日程，个人事项创建/保存/删除已在模拟器完成。已预约/已发布方案用 repository fixture 的真实 Flutter 渲染与回调验证，完整咨询业务链单列。新增/编辑弹窗和删除确认的精细视觉继续在独立条目验收。

- functional_evidence: [evidence/schedule/primary-regression.txt](../evidence/schedule/primary-regression.txt)
- functional_evidence: [evidence/schedule/primary-analyze.txt](../evidence/schedule/primary-analyze.txt)
- functional_evidence: [evidence/schedule/primary-build.json](../evidence/schedule/primary-build.json)
- functional_evidence: [evidence/schedule/delete-regression.txt](../evidence/schedule/delete-regression.txt)
- functional_evidence: [evidence/schedule/delete-result.json](../evidence/schedule/delete-result.json)
- functional_evidence: [evidence/accessibility/green.txt](../evidence/accessibility/green.txt)
- functional_evidence: [evidence/schedule-forms/verification.md](../evidence/schedule-forms/verification.md)
- visual_evidence: [evidence/schedule/schedule-current.png](../evidence/schedule/schedule-current.png)
- visual_evidence: [../../test/goldens/design_system/schedule-care-390.png](../../../test/goldens/design_system/schedule-care-390.png)
- visual_evidence: [../../test/goldens/design_system/schedule-plan-390.png](../../../test/goldens/design_system/schedule-plan-390.png)
- visual_evidence: [evidence/schedule-forms/updated.png](../evidence/schedule-forms/updated.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
