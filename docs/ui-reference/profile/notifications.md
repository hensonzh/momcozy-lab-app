# 通知收件箱

- ID：`profile/notifications`
- 类型：page
- 参考来源：derived-user-approved
- 设计源码：[通知收件箱（衍生设计）](../profile/derived/notifications.md#L1)，第 1–22 行
- Flutter：`lib/features/notifications/presentation/notifications_page.dart`
- Route / 入口：`/notifications`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：已按本页衍生规范分组并统一字号、间距与反馈。115 项认证/通知相关回归通过，三宽及 2x 验证；模拟器核对账号确认取消、通知空状态、设置刷新及返回。Google 真正关联、账号删除均只在测试替身验证；当前本地后台推送不可用，保持真实说明，不以 UI 验收代替推送投递验收。 Local reading typography reviewed on 2026-09-12: user paragraphs use the shared 1.55 role; 96 targeted regression tests and Android 1x/2x pass. See evidence/typography/local-reading/verification.md.

- functional_evidence: [evidence/account-notifications/verification.md](../evidence/account-notifications/verification.md)
- functional_evidence: [evidence/account-notifications/design-tests.txt](../evidence/account-notifications/design-tests.txt)
- functional_evidence: [evidence/account-notifications/regression.txt](../evidence/account-notifications/regression.txt)
- functional_evidence: [evidence/account-notifications/analyze.txt](../evidence/account-notifications/analyze.txt)
- functional_evidence: [evidence/account-notifications/build.txt](../evidence/account-notifications/build.txt)
- functional_evidence: [evidence/typography/local-reading/verification.md](../evidence/typography/local-reading/verification.md)
- functional_evidence: [evidence/typography/local-reading/regression.log](../evidence/typography/local-reading/regression.log)
- functional_evidence: [evidence/typography/local-reading/analyze.log](../evidence/typography/local-reading/analyze.log)
- functional_evidence: [evidence/typography/local-reading/native.log](../evidence/typography/local-reading/native.log)
- visual_evidence: [evidence/account-notifications/notifications-current-native.png](../evidence/account-notifications/notifications-current-native.png)
- visual_evidence: [../../test/goldens/design_system/notifications-inbox-390.png](../../../test/goldens/design_system/notifications-inbox-390.png)
- visual_evidence: [../../test/goldens/design_system/notifications-read-390.png](../../../test/goldens/design_system/notifications-read-390.png)
- visual_evidence: [../../test/goldens/design_system/notifications-error-390.png](../../../test/goldens/design_system/notifications-error-390.png)
- visual_evidence: [../../test/goldens/design_system/notifications-empty-390.png](../../../test/goldens/design_system/notifications-empty-390.png)
- visual_evidence: [evidence/typography/local-reading/native-reading-inbox-2x.png](../evidence/typography/local-reading/native-reading-inbox-2x.png)
- visual_evidence: [evidence/typography/local-reading/native-reading-settings-2x.png](../evidence/typography/local-reading/native-reading-settings-2x.png)
- visual_evidence: [evidence/typography/local-reading/native-reading-account-explanation-2x.png](../evidence/typography/local-reading/native-reading-account-explanation-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
