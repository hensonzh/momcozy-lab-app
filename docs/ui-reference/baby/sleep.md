# 睡眠记录

- ID：`baby/sleep`
- 类型：form
- 参考来源：original
- 设计源码：[BabyPage](../source/src/pages/UserApp.tsx#L1422)，第 1422–1934 行
- Flutter：`lib/modules/baby/presentation/baby_record_editor.dart`
- Route / 入口：`/baby /babies/:babyId/records`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/reference/sleep.png)

原始路径：`baby-me-style-sync/images/睡眠-390.png`；SHA-256：`bbf0101cb4ed3ab0532be9f6cb37fed1e608165dbd8e7af2d10a44a43d73d4e4`。


复核记录：按本页原始设计逐页核对。106 项回归、三宽/2x/键盘/草稿/重试通过；固定保存区及统一暖色表单。模拟器打开、切换、取消及返回已核对；多宝宝与写入使用受控测试，未向测试账号新增记录。切换入口语义点击区域错误有先失败后通过测试与设备复验。

- functional_evidence: [evidence/baby-editors/verification.md](../evidence/baby-editors/verification.md)
- functional_evidence: [evidence/baby-editors/regression.txt](../evidence/baby-editors/regression.txt)
- functional_evidence: [evidence/baby-editors/analyze.txt](../evidence/baby-editors/analyze.txt)
- functional_evidence: [evidence/baby-editors/build.json](../evidence/baby-editors/build.json)
- functional_evidence: [evidence/baby-secondary-states/verification.md](../evidence/baby-secondary-states/verification.md)
- visual_evidence: [evidence/baby-editors/baby-sleep-start-native.png](../evidence/baby-editors/baby-sleep-start-native.png)
- visual_evidence: [../../test/goldens/design_system/baby-sleep-start-390.png](../../../test/goldens/design_system/baby-sleep-start-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
