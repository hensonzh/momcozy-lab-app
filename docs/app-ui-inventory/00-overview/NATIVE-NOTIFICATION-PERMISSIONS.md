# Android 通知首次权限与拒绝恢复链

已沿真实用户入口完成 **2 条原生流程、23 个状态（19 个 App 窗口、4 个系统窗口）**。权限由实际 Android 插件读取与申请，系统按钮按 UIAutomator 当前节点定位后点击。业务接口、推送 Gateway、安装存储及测试账号采用隔离依赖；不代表真实 FCM 推送已配置或投递成功。

## 操作链

1. More → 通知 → 消息中心设置 → 开启 Appointments → 授权说明 → Continue → Android Allow → App 显示 Allowed 且分类开启 → 关闭分类 → 返回消息中心 → 返回 More。
2. 相同入口 → Android Don't allow → App 拒绝态及 Snackbar → 再开分类 → 系统设置说明 → Open settings → Android 总开关关闭 → 实际打开总开关 → 系统返回 → Refresh status → Allowed、分类仍关闭 → 开启再关闭分类 → 消息中心 → More。

两个分支均断言实际系统权限结果，以及隔离接口只收到 `appointments:true`、`appointments:false`。系统授权与服务端分类偏好是两个独立状态：恢复系统授权不会自动重开分类，关闭分类也不会撤销系统授权。

## 截图与长页面

23 张原图均已分段检查：[原图路径、尺寸与 SHA-256](native-permission-visual-review/sources.json)。12 张审阅图覆盖 46 个连续片段。此批所有页面在当前 1280 × 2856 原生视口内完整容纳，App 设置底部 Refresh status 和 More 底部导航均可见，未人为生成重复长图。

App 截图来自运行中的 Flutter surface；系统截图来自 adb 完整屏幕。原生弹窗后方仍可见尚未退出动画的 App 授权说明，保留实际合成画面。拒绝 Snackbar 也保留当前遮挡关系。系统界面条目的 `/notifications/settings` 是其下方 App 路由，系统窗口归属以对应 XML 为准。

 | 审阅图 | 审阅图 | 审阅图 |
| --- | --- | --- |
| [分段 01](native-permission-visual-review/sheet-01.png) | [分段 02](native-permission-visual-review/sheet-02.png) | [分段 03](native-permission-visual-review/sheet-03.png) |
| [分段 04](native-permission-visual-review/sheet-04.png) | [分段 05](native-permission-visual-review/sheet-05.png) | [分段 06](native-permission-visual-review/sheet-06.png) |
| [分段 07](native-permission-visual-review/sheet-07.png) | [分段 08](native-permission-visual-review/sheet-08.png) | [分段 09](native-permission-visual-review/sheet-09.png) |
| [分段 10](native-permission-visual-review/sheet-10.png) | [分段 11](native-permission-visual-review/sheet-11.png) | [分段 12](native-permission-visual-review/sheet-12.png) |

## 验证与环境恢复

- 允许分支：1 PASS，测试步骤 11 秒。[日志](native-permission-allow-final.log)、[精确命令](native-permission-allow-final.command.json)、[结果](../native/notification-permission/native-permission-allow-result.json)。
- 拒绝恢复分支：1 PASS，测试步骤 26 秒。[日志](native-permission-deny-final.log)、[精确命令](native-permission-deny-final.command.json)、[结果](../native/notification-permission/native-permission-deny-result.json)。
- 全仓静态检查 No issues found：[日志](native-permission-analyze.log)。测试格式检查无改动；采集、索引和验证 Python 脚本编译检查通过。
- 两次执行均在 finally 中恢复原 APK、POST_NOTIFICATIONS 权限及其 flags、原先不存在的插件请求历史文件；没有卸载或清空 App 数据。恢复原登录 Mia 首页的断言通过：[允许恢复](../native/notification-permission/allow-restore.json)、[拒绝恢复](../native/notification-permission/deny-restore.json)、[允许后首页](../native/notification-permission/allow-restored-home.png)、[拒绝后首页](../native/notification-permission/deny-restored-home.png)。
- 本轮整理报告时再次执行脚本 `--check-only`，当前安装 APK SHA、权限及插件历史仍与原基线匹配。该检查不重跑上述原生流程。

早期采集曾因手动门闩超时、残留系统权限 Activity、英文 Back 与中文界面的本地化不符而失败。最终工具会识别本 App 残留请求，测试使用 MaterialLocalizations 的实际返回标签；没有修改生产页面。失败诊断日志保留，不计入成功证据。

复现工具位于 `scripts/capture-native-notification-permissions.py`，原生测试为 `integration_test/notification_native_permission_test.dart`。该工具专用于本机 emulator-5554，依赖 `/tmp/momcozy-native-permission-backup/backup.json` 中事前保存的原 APK、权限与插件历史基线，执行前会校验实际环境仍匹配；不是任意账号或设备的一键重置脚本。

```sh
python3 scripts/capture-native-notification-permissions.py --branch deny --check-only
python3 scripts/capture-native-notification-permissions.py --branch deny
python3 scripts/capture-native-notification-permissions.py --branch allow
```

## 逐状态索引

[原生清单](../native/permission-manifest.json) 记录每张 PNG、测试源 SHA、系统 XML SHA、正常入口和前驱关系。

| 状态 | 实际操作 | 页面及前驱证据 |
| --- | --- | --- |
| 通知权限流程起点 More（拒绝恢复链） | Authenticated More entry | [状态与截图](../07-me/native-permission-deny-more/README.md) |
| 空消息中心（拒绝恢复链） | Tap notifications → actual empty inbox | [状态与截图](../07-me/native-permission-deny-inbox/README.md) |
| 通知设置未申请（拒绝恢复链） | Inbox toolbar → not requested, category off | [状态与截图](../07-me/native-permission-deny-not-requested/README.md) |
| 通知权限说明弹窗（拒绝恢复链） | Enable category → App permission explanation | [状态与截图](../07-me/native-permission-deny-education/README.md) |
| Android 首次通知申请（拒绝恢复链） | App Continue → actual Android request; choose deny | [状态与截图](../10-global-modals/native-permission-deny-system-request/README.md) |
| 系统拒绝后的通知设置（拒绝恢复链） | Android deny → permission refreshed and category result | [状态与截图](../07-me/native-permission-deny-denied/README.md) |
| 通知拒绝后的设置引导（拒绝恢复链） | Enable after denial → offer Android settings | [状态与截图](../07-me/native-permission-deny-settings-offer/README.md) |
| Android 通知总开关关闭（拒绝恢复链） | App Open settings → Android notification master switch off | [状态与截图](../10-global-modals/native-permission-deny-system-settings-off/README.md) |
| Android 通知总开关开启（拒绝恢复链） | Turn on Android master switch → enabled; system Back returns to App | [状态与截图](../10-global-modals/native-permission-deny-system-settings-on/README.md) |
| 系统设置允许后返回 App（拒绝恢复链） | Allow in Android settings and return → App refresh | [状态与截图](../07-me/native-permission-deny-settings-allowed/README.md) |
| 允许后开启预约分类（拒绝恢复链） | Enable category after system permission → isolated preference saved | [状态与截图](../07-me/native-permission-deny-category-enabled/README.md) |
| 关闭预约分类且保留系统权限（拒绝恢复链） | Disable service category; Android permission remains allowed | [状态与截图](../07-me/native-permission-deny-category-disabled/README.md) |
| 返回消息中心（拒绝恢复链） | App back → inbox | [状态与截图](../07-me/native-permission-deny-inbox-return/README.md) |
| 返回原 More（拒绝恢复链） | Inbox back → original More | [状态与截图](../07-me/native-permission-deny-more-return/README.md) |
| 通知权限流程起点 More（首次允许链） | Authenticated More entry | [状态与截图](../07-me/native-permission-allow-more/README.md) |
| 空消息中心（首次允许链） | Tap notifications → actual empty inbox | [状态与截图](../07-me/native-permission-allow-inbox/README.md) |
| 通知设置未申请（首次允许链） | Inbox toolbar → not requested, category off | [状态与截图](../07-me/native-permission-allow-not-requested/README.md) |
| 通知权限说明弹窗（首次允许链） | Enable category → App permission explanation | [状态与截图](../07-me/native-permission-allow-education/README.md) |
| Android 首次通知申请（首次允许链） | App Continue → actual Android request; choose allow | [状态与截图](../10-global-modals/native-permission-allow-system-request/README.md) |
| 系统允许后的通知设置（首次允许链） | Android allow → permission refreshed and category result | [状态与截图](../07-me/native-permission-allow-allowed/README.md) |
| 关闭预约分类且保留系统权限（首次允许链） | Disable service category; Android permission remains allowed | [状态与截图](../07-me/native-permission-allow-category-disabled/README.md) |
| 返回消息中心（首次允许链） | App back → inbox | [状态与截图](../07-me/native-permission-allow-inbox-return/README.md) |
| 返回原 More（首次允许链） | Inbox back → original More | [状态与截图](../07-me/native-permission-allow-more-return/README.md) |

## 仍未完成的范围

通知真实投递、前台提示、系统通知点击和冷启动、跨账号延迟消息、iOS 系统层、提醒注册等待/失败及其他目标链仍需按实际可达性继续验证。Android 设置中开启后出现的通知圆点、未使用分类等更深系统入口未遍历。其他相机/麦克风权限分支、其余模块交互以及全体长图审阅也仍在总目标范围内。

本报告补齐首次通知权限的原生交互证据，不证明全部 App 的 Page × State × Interaction 盘点完成；文件完整性 PASS 也不能代替覆盖验收。


后续 App 层设备注册等待/失败/重试与消息中心 Tooltip 已补齐，隐私通知入口也已核对到已有运行证据，详见 [后续报告](NOTIFICATION-FOLLOWUP.md)。上文剩余范围中的这些子项据此更新；原生推送投递仍未完成。
