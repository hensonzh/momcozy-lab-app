# 页面不存在

- ID：`common/not-found`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[页面不存在（衍生设计）](../common/derived/not-found.md#L1)，第 1–22 行
- Flutter：`lib/app/momcozy_app.dart`
- Route / 入口：`/404`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：7 项专用与 58 项关联回归通过；实际未知原生路由及返回首页已核对。移除内部技术文案，保留认证边界；首次返回资料失败重试后恢复 Mia。

- functional_evidence: [evidence/not-found/verification.md](../evidence/not-found/verification.md)
- functional_evidence: [evidence/not-found/design-tests.txt](../evidence/not-found/design-tests.txt)
- functional_evidence: [evidence/not-found/regression.txt](../evidence/not-found/regression.txt)
- functional_evidence: [evidence/not-found/analyze.txt](../evidence/not-found/analyze.txt)
- functional_evidence: [evidence/not-found/build.json](../evidence/not-found/build.json)
- visual_evidence: [evidence/not-found/not-found-native.png](../evidence/not-found/not-found-native.png)
- visual_evidence: [../../test/goldens/design_system/not-found-390.png](../../../test/goldens/design_system/not-found-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
