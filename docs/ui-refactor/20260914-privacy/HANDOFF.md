# 隐私与数据：Figma → Flutter

本轮完成 `/privacy` 的增量重构。全量页面重构任务仍在进行中。

已有截图中，账号记录、服务选择、必要与可选授权的层级较接近，长用途说明与开关挤在同一行。本次按妈妈页设计基准，将账号记录放入浅粉说明卡，每项授权独立成卡，用途说明占满宽度，关闭影响使用浅米色区域。正常字号下标题与开关并排，双倍字号时上下排列。

## 设计与截图依据

- [Figma 默认页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=142-387)
- [授权组件 MomCozy/ConsentRow](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=142-377)
- [关闭授权确认](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=142-1199)
- [320 宽度、双倍字号](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=142-1403)
- 21 个状态画板及交付说明见 [节点清单](figma-nodes.json)。涵盖默认、加载、读取失败、空服务、指定服务不存在、编辑、保存中、已保存、结果不确定、部分完成、版本冲突、服务切换、撤回与离开确认、长服务名。
- [源截图索引](source-inventory.json)记录 41 个已有 `/privacy` 截图条目。离开后回到 More、打开通知设置等其他路由截图不计入隐私页完成数量。
- 本地 Figma 预览：[默认](figma-default.png)、[确认弹窗](figma-confirm.png)、[大字体](figma-large.png)。这些是设计参考；Flutter 保留原生开关的可访问性触控尺寸、原生选择器和弹窗滚动行为。

先使用实际 Figma 工具创建组件与页面状态，再读取设计上下文实现 Flutter，随后对照 Widget 截图调整设计标注。

## 实现范围

- `lib/modules/profile/presentation/privacy_page.dart` 接入 `MomHomeTokens`、`momSettingsTheme` 和 `MomSettingsCard`，调整说明、授权卡、加载与保存反馈。
- `MomSettingsDialog` 增加可选 `closeLabel`，供隐私流程保留原有“关闭”操作；账号和通知弹窗默认布局不变。
- 继续使用 `ProductErrorView`、`DropdownButtonFormField<String>`、带原 key 与语义标签的 `Switch`。保留返回 TextButton、所有用途及影响文案、通知管理入口。
- 未修改隐私控制器、仓库、接口、版本检查或路由。保存中禁止操作，撤回必要授权仍需确认；不确定结果保留重试和重新读取；冲突必须重新读取；切换服务或离开时仍保护未保存草稿。

## 验证

最终 70 项测试通过，静态分析 3 个文件无问题。日志见 [测试结果](tests.log) 和 [分析结果](analyze.log)。

- 原隐私测试 14 项，覆盖 320/390/430 宽度、1x/2x 字号、撤回确认、保存、通知入口、服务切换、错误与控制器恢复行为。
- 新增状态测试 10 项，覆盖加载、长服务名、关闭/取消保留草稿、保存禁用、待确认结果、版本冲突以及部分成功后只重试未完成写入。
- 同时回归账号、通知和 More 页，确认共享弹窗的默认使用方未受影响。
- 更新隐私原有 21 张视觉基线，新增 26 张状态基线。已检查正常字号与窄屏大字体的关键截图；未重采集 Session A 的截图，也未执行其 inventory writer 测试。

复验命令：

```sh
flutter test --no-pub test/modules/profile/privacy_test.dart test/modules/profile/privacy_redesign_states_test.dart test/features/auth/account_page_test.dart test/features/auth/account_redesign_states_test.dart test/features/notifications/notification_widgets_test.dart test/features/notifications/notification_redesign_states_test.dart test/features/notifications/notification_design_test.dart test/features/notifications/notifications_page_test.dart test/app/more_design_test.dart test/app/more_redesign_states_test.dart
flutter analyze --no-pub lib/modules/profile/presentation/privacy_page.dart lib/shared/widgets/mom_settings_widgets.dart test/modules/profile/privacy_redesign_states_test.dart
```

本轮没有运行原生设备验证、构建或发布。

## 增量队列

交付时观察到 2,212 个截图状态，比本轮开始新增 62 个通知相关状态，无已知条目内容变更或删除。新增项已保存到 [待审队列](../pending-inventory.json)，未自动标为设计完成。目前队列仍有 144 个待审条目，状态数量不等于页面数量。

下一步先核对通知新增状态和此前 More/账号的待审状态是否被现有设计覆盖，再继续已有截图且尚未重构的页面。完整任务范围保持不变。
