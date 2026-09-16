# 宝宝历史记录

- ID：`baby/records`
- 类型：page
- 参考来源：original
- 设计源码：[RecordsPage](../source/src/pages/UserApp.tsx#L1934)，第 1934–1970 行
- Flutter：`lib/modules/baby/presentation/baby_records_page.dart`
- Route / 入口：`/babies/:babyId/records`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/records-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`cb240fd60206dd5bb6ccfe9813acaba42113a5f47892ec6fcf2da0d27dd6388f`。

[查看参考图](../baby/records-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`38df25a568b5999fb611e8168f91fc5d075eed8be7b4c37a41852f5d8ba53540`。


复核记录：RecordsPage 标题、分类与记录卡复核，补齐数据来源折叠及真实 /privacy 导航；月份、编辑、删除、撤销及分页保留，未复制模拟离线队列。三宽/双倍字号验证来源导航和原记录操作；整合 445 项通过。完整五开关隐私页的契约差异独立记录，不冒充宝宝页保存能力。 Empty-state start alignment updated to match the original EmptyState reference; see shared feedback evidence.

- functional_evidence: [../../test/modules/baby/baby_pages_test.dart](../../../test/modules/baby/baby_pages_test.dart)
- functional_evidence: [evidence/privacy/verification.md](../evidence/privacy/verification.md)
- functional_evidence: [evidence/privacy/regression.log](../evidence/privacy/regression.log)
- functional_evidence: [evidence/privacy/analyze.log](../evidence/privacy/analyze.log)
- functional_evidence: [evidence/feedback/verification.md](../evidence/feedback/verification.md)
- visual_evidence: [baby/records-full.png](../baby/records-full.png)
- visual_evidence: [../../test/goldens/design_system/baby-history-390.png](../../../test/goldens/design_system/baby-history-390.png)
- visual_evidence: [../../test/goldens/design_system/baby-history-source-390.png](../../../test/goldens/design_system/baby-history-source-390.png)
- visual_evidence: [evidence/privacy/native-baby-source.png](../evidence/privacy/native-baby-source.png)
- visual_evidence: [evidence/privacy/native-return-records.png](../evidence/privacy/native-return-records.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
