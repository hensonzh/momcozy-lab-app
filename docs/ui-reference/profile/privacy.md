# 信息授权管理

- ID：`profile/privacy`
- 类型：page
- 参考来源：original
- 设计源码：[PrivacyPage](../source/src/pages/UserApp.tsx#L1970)，第 1970–2068 行
- Flutter：`lib/modules/profile/presentation/privacy_page.dart`
- Route / 入口：`/privacy`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Need Review**



[查看参考图](../profile/privacy-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`05697c42eff5798a7ecdf57e322929de403787a5cc123cd733d34acb73064943`。

[查看参考图](../profile/privacy-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`8ca378ea8c1a1784b9c8bf3e6167b581a94acb2857abc36261032443e941f738`。


复核记录：独立 /privacy 已实现，More 与宝宝来源入口接通。ibclcCase/video/aiContext 按服务读取、保存，具备撤销确认、CAS、部分成功重试、冲突重新读取。app_service 无全局契约；服务 notifications 存储未接入提醒发送，改为现有通知设置入口。与原五开关设计有实质差异，仍 Need Review；详见 evidence/privacy/verification.md。

- functional_evidence: [../../test/modules/profile/privacy_test.dart](../../../test/modules/profile/privacy_test.dart)
- functional_evidence: [evidence/privacy/verification.md](../evidence/privacy/verification.md)
- functional_evidence: [evidence/privacy/regression.log](../evidence/privacy/regression.log)
- functional_evidence: [evidence/privacy/analyze.log](../evidence/privacy/analyze.log)
- visual_evidence: [profile/privacy-full.png](../profile/privacy-full.png)
- visual_evidence: [../../test/goldens/design_system/privacy-top-390.png](../../../test/goldens/design_system/privacy-top-390.png)
- visual_evidence: [../../test/goldens/design_system/privacy-saved-390.png](../../../test/goldens/design_system/privacy-saved-390.png)
- visual_evidence: [../../test/goldens/design_system/privacy-confirm-320-2x.png](../../../test/goldens/design_system/privacy-confirm-320-2x.png)
- visual_evidence: [evidence/privacy/native-privacy-empty.png](../evidence/privacy/native-privacy-empty.png)
- visual_evidence: [evidence/privacy/native-more-privacy.png](../evidence/privacy/native-more-privacy.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
