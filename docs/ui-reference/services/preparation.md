# 预约与咨询准备

- ID：`services/preparation`
- 类型：page
- 参考来源：original
- 设计源码：[HomeConsultPreparation](../source/src/pages/UserApp.tsx#L554)，第 554–587 行
- Flutter：`lib/modules/consultation/presentation/room_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/preparation-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`7f1f49c0d67af0e1654317d9c3c5a88e874b2bbcc20b1f80f6474de645e7d77a`。


复核记录：按当前 HomeConsultPreparation 的居中预约详情结构重构；真实时区、每秒倒计时、取消和开始并列，大字号纵向。新增 8 项测试覆盖时间与资料门禁、服务禁用、测试提前进入、取消中锁定和返回刷新。原生保留独立 room 路由；主页服务状态和真实双端咨询继续另行验收。 Home preparation overlay and shared preparation style verified; see home-preparation evidence.

- functional_evidence: [../../test/modules/consultation/consultation_preparation_test.dart](../../../test/modules/consultation/consultation_preparation_test.dart)
- functional_evidence: [evidence/preparation/regression.log](../evidence/preparation/regression.log)
- functional_evidence: [evidence/preparation/analyze.log](../evidence/preparation/analyze.log)
- functional_evidence: [evidence/preparation/verification.md](../evidence/preparation/verification.md)
- functional_evidence: [evidence/home-preparation/verification.md](../evidence/home-preparation/verification.md)
- visual_evidence: [services/preparation-viewport.png](../services/preparation-viewport.png)
- visual_evidence: [../../test/goldens/design_system/preparation-ready-320.png](../../../test/goldens/design_system/preparation-ready-320.png)
- visual_evidence: [../../test/goldens/design_system/preparation-ready-390.png](../../../test/goldens/design_system/preparation-ready-390.png)
- visual_evidence: [../../test/goldens/design_system/preparation-ready-430.png](../../../test/goldens/design_system/preparation-ready-430.png)
- visual_evidence: [../../test/goldens/design_system/preparation-ready-320-2x.png](../../../test/goldens/design_system/preparation-ready-320-2x.png)
- visual_evidence: [evidence/preparation/verification.md](../evidence/preparation/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
