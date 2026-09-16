# 专家服务列表

- ID：`services/catalog`
- 类型：page
- 参考来源：original
- 设计源码：[ServicesPage](../source/src/pages/UserApp.tsx#L3275)，第 3275–3304 行
- Flutter：`lib/modules/services/presentation/service_catalog_page.dart`
- Route / 入口：`/services`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/catalog-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`c2110f9a94890bd386c1816aba0c059ed0d7d670840bf2a2a85b11f2984ced93`。

[查看参考图](../services/catalog-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`39ccc0fb3f00bf355b3bcaf28b36f55c53eee166e1d574bb73692c09d0e7a7f4`。


复核记录：已逐页重新查看源码与当前设计截图，完成方案卡、服务元数据、团队入口/资料弹窗和详情交付列表。43 项设计状态测试、74 项 services 回归通过；三宽及 2x 字号验证。模拟器完成目录、团队、详情、购买前确认及返回，不提交订单。API 无头像字段使用中性图标，保留已购/继续付款原入口；有专家、已购与待付款状态另有 Flutter 金图证据。 2026-09-12 再次逐项核对四类方案，补齐刷新/空/忙碌反馈、大字号返回；见 catalog-states 证据。

- functional_evidence: [evidence/services/verification.md](../evidence/services/verification.md)
- functional_evidence: [evidence/services/design-tests.txt](../evidence/services/design-tests.txt)
- functional_evidence: [evidence/services/regression.txt](../evidence/services/regression.txt)
- functional_evidence: [evidence/services/analyze.txt](../evidence/services/analyze.txt)
- functional_evidence: [evidence/services/build.txt](../evidence/services/build.txt)
- functional_evidence: [evidence/catalog-states/verification.md](../evidence/catalog-states/verification.md)
- visual_evidence: [evidence/services/services-catalog-native.png](../evidence/services/services-catalog-native.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
