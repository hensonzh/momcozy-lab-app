# 咨询前原生摄像头与麦克风权限补验

本轮在 Android emulator-5554 上运行生产 App 路由、咨询前设备检测组件和 LiveKit 本地轨道，通过 UIAutomator 实际点击系统授权按钮。HTTP 与账号会话使用隔离测试数据；没有加入远端房间，没有提交业务数据。此项覆盖 App 权限交互，不表示云端咨询音视频通信已经验证。

## 实际执行链

More → Me → 查看预约 → 开始咨询 → Android 摄像头拒绝 → Android 麦克风拒绝 → App 检测失败 → 开始检测 → Android 摄像头允许 → Android 麦克风允许 → App 检测成功 → 重新检查成功 → 继续确认 → 开始视频咨询确认 → 关闭 → 妈妈首页 → More。

4 张系统图截于实际选择之前，XML 及 `clicked_control` 记录随后实际点击的控件。系统选择后的结果另有 App 截图和状态断言。11 个 App 观察点、4 个系统观察点共同形成有序前驱链。

| 状态 | 操作 / 到达条件 | 当前完整截图 |
| --- | --- | --- |
| [设备检测起点 More](../07-me/native-device-more/README.md) | Authenticated More entry | [图](../native/consultation-devices/native-device-more.png) |
| [妈妈首页待进行预约](../03-mom/native-device-mom/README.md) | Bottom Me → home with isolated active appointment | [图](../native/consultation-devices/native-device-mom-long.png) |
| [咨询准备弹窗](../03-mom/native-device-appointment/README.md) | View appointment → actual preparation dialog | [图](../native/consultation-devices/native-device-appointment.png) |
| [首次检测请求中](../03-mom/native-device-checking/README.md) | Start consultation → device checking before native permission response | [图](../native/consultation-devices/native-device-checking.png) |
| [Android 摄像头申请（拒绝）](../10-global-modals/native-device-deny-camera/README.md) | Actual Android camera permission → choose deny | [图](../native/consultation-devices/native-device-deny-camera.png) |
| [Android 麦克风申请（拒绝）](../10-global-modals/native-device-deny-microphone/README.md) | Actual Android microphone permission → choose deny | [图](../native/consultation-devices/native-device-deny-microphone.png) |
| [拒绝摄像头及麦克风后的检测失败](../03-mom/native-device-denied/README.md) | Deny camera and microphone → actual device errors | [图](../native/consultation-devices/native-device-denied.png) |
| [重新申请设备权限](../03-mom/native-device-retry-checking/README.md) | Retry device check → requesting permissions again | [图](../native/consultation-devices/native-device-retry-checking.png) |
| [Android 再次申请摄像头（允许）](../10-global-modals/native-device-allow-camera/README.md) | Actual Android camera permission → choose allow | [图](../native/consultation-devices/native-device-allow-camera.png) |
| [Android 再次申请麦克风（允许）](../10-global-modals/native-device-allow-microphone/README.md) | Actual Android microphone permission → choose allow | [图](../native/consultation-devices/native-device-allow-microphone.png) |
| [允许后设备检测成功](../03-mom/native-device-ready/README.md) | Allow camera and microphone → actual local tracks created and released | [图](../native/consultation-devices/native-device-ready.png) |
| [已授权设备再次检测成功](../03-mom/native-device-rechecked/README.md) | Recheck with granted permissions → ready without system prompt | [图](../native/consultation-devices/native-device-rechecked.png) |
| [设备检测后开始咨询确认](../03-mom/native-device-start-confirm/README.md) | Device check continue → actual consultation confirmation, no room join | [图](../native/consultation-devices/native-device-start-confirm.png) |
| [关闭咨询确认返回妈妈首页](../03-mom/native-device-mom-return/README.md) | Close consultation confirmation → home | [图](../native/consultation-devices/native-device-mom-return-long.png) |
| [返回 More](../07-me/native-device-more-return/README.md) | Bottom More → original tab | [图](../native/consultation-devices/native-device-more-return.png) |

## 长图与视觉核验

- 两张妈妈页长图为实际 ScrollPosition 滚动拼接，完整覆盖 y=0…1186 dp，固定导航仅保留一次。系统弹窗与 App 检测/确认浮层内容均能在当前原生视口内完整呈现，没有拼接其背景页面充当浮层长图。
- 17 张交互/长图及一张恢复后首页，共 18 张原图拆为 58 个连续片段、15 张审阅图，全部逐张查看。已确认失败文案、两个实际系统权限说明、成功状态、继续确认按钮、授权未完成的咨询确认界面以及最终首页恢复。见 [原图 SHA 与分段记录](native-device-visual-review/sources.json)。
- 检测成功说明本地摄像头轨道和麦克风轨道可以创建，生产检测器随后释放轨道；未采集用户媒体，也未发布至房间。
- 开始视频咨询确认页仍显示当前州和本次服务的视频授权提醒。原生设备权限与业务服务授权是不同条件，本轮没有点击业务授权或入会按钮。

## 测试及恢复

- [最终运行日志](native-device-final.log)：1 项集成测试通过，测试步骤 23 秒；Gradle 编译 15.3 秒。构建使用固定 Android SDK / Java 17 及本地 AAPT2 路径。
- [完整运行命令](native-device-final.command.json)、[断言结果](../native/consultation-devices/native-device-result.json)、[状态与源哈希清单](../native/device-manifest.json)、[系统操作元数据](../native/consultation-devices/native-device-system-journeys.json)。
- [全仓静态检查](native-device-analyze.log)：No issues found。
- 首次运行测试数据遗漏 `/v1/care/episodes/service-episode/booking`，首页如实显示预约暂未载入，测试未能进入查看预约。补齐已有接口的隔离响应后重跑通过；保留 [首次诊断日志](native-device-attempt1-missing-booking.log)，没有改动产品业务代码。
- 宿主 finally 恢复原 APK，SHA-256 为 `8395f439039d8f47aba0b0253942a3b875c1969f9ed9f570650420e558403d51`。两项权限恢复为未授权，原权限 flags 完全一致；Mia 首页可见。未卸载、未清空 App 数据。见 [恢复记录](../native/consultation-devices/restore.json)、[恢复截图](../native/consultation-devices/restored-home.png)、[UI 层级](../native/consultation-devices/restored-home.xml)。通知原生检查脚本随后再次只读校验通过。

复现入口：`python3 scripts/capture-native-consultation-devices.py`。依赖本机 `/tmp/momcozy-native-permission-backup/backup.json` 中的原始 APK 备份，脚本在初始 APK 或权限状态改变时拒绝执行；不是可在任意账号/设备上直接重置权限的通用脚本。

源码：`integration_test/consultation_native_device_test.dart`、`scripts/capture-native-consultation-devices.py`。索引与完整性验证器新增 native/device-manifest 的支持，宿主截图采集器未改变。

## 范围边界与剩余工作

本轮证据补上真实相机/麦克风的拒绝及重试允许链。当前设备上的单次允许、连续拒绝后系统不再提示、系统设置撤销后回到 App 等分支尚未纳入此原生流程；其它模块剩余交互和全部长图的逐项审阅也尚未完成。整体完整 UI Inventory 目标保持未完成。
