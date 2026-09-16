# 生长曲线

- ID：`baby/growth`
- 类型：section
- 参考来源：original
- 设计源码：[BabyGrowthCurve](../source/src/pages/UserApp.tsx#L1363)，第 1363–1422 行
- Flutter：`lib/modules/baby/presentation/baby_growth_curve.dart`
- Route / 入口：`/baby`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/reference/growth.png)

原始路径：`baby-me-style-sync/images/growth-390.png`；SHA-256：`b4f61a4c232aa44329b7d35e1506816057b484b192f85f9c71e77624e60cfb4f`。


复核记录：已对照最新 baby.css 与 Me 共用知识卡片：页头、卡片、指标、图标、图表表面/切换器、睡眠监测布局已统一；旧 compact 知识卡片移除。320/390/430 金图和两倍字号/滚动通过；本地 APK 冷启动与新增体重→首页/曲线更新通过。记录弹窗、切换器、知识详情及独立异常状态在各自条目继续验收。图表坐标范围由现有真实记录与 WHO 模型计算，专家/临床逻辑未改。

- functional_evidence: [evidence/baby/verification.txt](../evidence/baby/verification.txt)
- functional_evidence: [evidence/baby/interaction-results.json](../evidence/baby/interaction-results.json)
- functional_evidence: [evidence/baby-feedback/verification.md](../evidence/baby-feedback/verification.md)
- visual_evidence: [evidence/baby/home-native.png](../evidence/baby/home-native.png)
- visual_evidence: [evidence/baby/growth-native.png](../evidence/baby/growth-native.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
