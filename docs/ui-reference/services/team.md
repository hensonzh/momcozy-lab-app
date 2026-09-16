# 专家团队

- ID：`services/team`
- 类型：dialog
- 参考来源：original
- 设计源码：[ServiceExpertTeamModal](../source/src/pages/UserApp.tsx#L154)，第 154–167 行
- Flutter：`lib/modules/services/presentation/service_catalog_page.dart`
- Route / 入口：`/services/:packageId`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/team-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`544ed94a9d2d260e9909e1f89b3fd97528c4d085ad6953b807b1fc758f918576`。


复核记录：已逐页重新查看源码与当前设计截图，完成方案卡、服务元数据、团队入口/资料弹窗和详情交付列表。43 项设计状态测试、74 项 services 回归通过；三宽及 2x 字号验证。模拟器完成目录、团队、详情、购买前确认及返回，不提交订单。API 无头像字段使用中性图标，保留已购/继续付款原入口；有专家、已购与待付款状态另有 Flutter 金图证据。

- functional_evidence: [evidence/services/verification.md](../evidence/services/verification.md)
- functional_evidence: [evidence/services/design-tests.txt](../evidence/services/design-tests.txt)
- functional_evidence: [evidence/services/regression.txt](../evidence/services/regression.txt)
- functional_evidence: [evidence/services/analyze.txt](../evidence/services/analyze.txt)
- functional_evidence: [evidence/services/build.txt](../evidence/services/build.txt)
- visual_evidence: [evidence/services/services-team-native.png](../evidence/services/services-team-native.png)
- visual_evidence: [../../test/goldens/design_system/service-team-populated-390.png](../../../test/goldens/design_system/service-team-populated-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
