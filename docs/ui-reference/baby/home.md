# Baby 首页

- ID：`baby/home`
- 类型：page
- 参考来源：original
- 设计源码：[BabyPage](../source/src/pages/UserApp.tsx#L1422)，第 1422–1934 行
- Flutter：`lib/modules/baby/presentation/baby_home_page.dart`
- Route / 入口：`/baby`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/reference/home.png)

原始路径：`baby-me-style-sync/images/home-390.png`；SHA-256：`6d2e099f8c77605c399d2299dfe4a5f848a3a1560aa900bf9b9a3a84294e97d0`。

[查看参考图](../baby/home-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`f08dec9c17df17c0d16bd99f706ffe03a3f1ca721f31be70d9fe65aa1608c875`。

[查看参考图](../baby/home-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`8ecfe9b9737c0da725472f7f9fc65ccbac65ccb85051c6b6f9e41d8b7701eb0e`。


复核记录：已对照最新 baby.css 与 Me 共用知识卡片：页头、卡片、指标、图标、图表表面/切换器、睡眠监测布局已统一；旧 compact 知识卡片移除。320/390/430 金图和两倍字号/滚动通过；本地 APK 冷启动与新增体重→首页/曲线更新通过。记录弹窗、切换器、知识详情及独立异常状态在各自条目继续验收。图表坐标范围由现有真实记录与 WHO 模型计算，专家/临床逻辑未改。

- functional_evidence: [evidence/baby/verification.txt](../evidence/baby/verification.txt)
- functional_evidence: [evidence/baby/interaction-results.json](../evidence/baby/interaction-results.json)
- functional_evidence: [evidence/accessibility/green.txt](../evidence/accessibility/green.txt)
- functional_evidence: [evidence/baby-feedback/verification.md](../evidence/baby-feedback/verification.md)
- visual_evidence: [evidence/baby/home-native.png](../evidence/baby/home-native.png)
- visual_evidence: [evidence/baby/growth-native.png](../evidence/baby/growth-native.png)
- visual_evidence: [evidence/baby-feedback/saved.png](../evidence/baby-feedback/saved.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
