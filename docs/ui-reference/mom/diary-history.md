# 独立日记编辑页

- ID：`mom/diary-history`
- 类型：page
- 参考来源：derived-user-approved
- 设计源码：[独立日记编辑页（衍生设计）](../mom/derived/diary-history.md#L1)，第 1–22 行
- Flutter：`lib/modules/mom/presentation/mother_diary_page.dart`
- Route / 入口：`/me/diary`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：衍生设计：独立路由复用已确认的日记编辑器，修复 section 路由切换保留旧分类及 SafeArea 底色。68 项妈妈模块与路由回归通过，覆盖 320/390/430、2x 字号、短屏键盘、离线重试、离开确认；模拟器读取既有记录、三分类切换、草稿放弃后返回 Mia 首页均通过。 后续共享字段和空表提示改进详见 diary-states，最终相关回归为 77 项。

- functional_evidence: [evidence/diary-page/verification.md](../evidence/diary-page/verification.md)
- functional_evidence: [evidence/diary-page/regression.log](../evidence/diary-page/regression.log)
- functional_evidence: [../../test/modules/mom/mother_diary_page_test.dart](../../../test/modules/mom/mother_diary_page_test.dart)
- functional_evidence: [../../test/modules/mom/mother_diary_test.dart](../../../test/modules/mom/mother_diary_test.dart)
- functional_evidence: [evidence/diary-page/native-return-home.xml](../evidence/diary-page/native-return-home.xml)
- visual_evidence: [evidence/diary-page/native-rest.png](../evidence/diary-page/native-rest.png)
- visual_evidence: [evidence/diary-page/native-body.png](../evidence/diary-page/native-body.png)
- visual_evidence: [evidence/diary-page/native-mood.png](../evidence/diary-page/native-mood.png)
- visual_evidence: [evidence/diary-page/native-discard.png](../evidence/diary-page/native-discard.png)
- visual_evidence: [../../test/goldens/design_system/diary-page-keyboard-320-2x.png](../../../test/goldens/design_system/diary-page-keyboard-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
