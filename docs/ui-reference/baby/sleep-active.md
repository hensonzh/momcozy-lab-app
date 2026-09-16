# 正在睡眠

- ID：`baby/sleep-active`
- 类型：state
- 参考来源：original
- 设计源码：[BabyPage](../source/src/pages/UserApp.tsx#L1422)，第 1422–1934 行
- Flutter：`lib/modules/baby/presentation/baby_record_editor.dart`
- Route / 入口：`/baby /babies/:babyId/records`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/reference/sleep-active.png)

原始路径：`baby-me-style-sync/images/sleep-active.png`；SHA-256：`f6dddcacf08621b6f4b4e657f3ed844f86d081245b054b2f1b7e2994bf015f04`。


复核记录：独立原图与源码已重新复核，三宽、双倍字号功能及实际 Flutter 截图通过。睡眠保留折叠的时间备注调整入口；长昵称短屏保留完整字段，键盘出现压缩标题并维持关闭保存可达。原生回归未写入真实宝宝记录。

- functional_evidence: [evidence/baby-secondary-states/verification.md](../evidence/baby-secondary-states/verification.md)
- functional_evidence: [evidence/baby-secondary-states/regression.txt](../evidence/baby-secondary-states/regression.txt)
- functional_evidence: [evidence/baby-secondary-states/analyze.txt](../evidence/baby-secondary-states/analyze.txt)
- functional_evidence: [evidence/baby-secondary-states/build.json](../evidence/baby-secondary-states/build.json)
- visual_evidence: [../../test/goldens/design_system/baby-sleep-active-320.png](../../../test/goldens/design_system/baby-sleep-active-320.png)
- visual_evidence: [../../test/goldens/design_system/baby-sleep-active-390.png](../../../test/goldens/design_system/baby-sleep-active-390.png)
- visual_evidence: [../../test/goldens/design_system/baby-sleep-active-430.png](../../../test/goldens/design_system/baby-sleep-active-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
