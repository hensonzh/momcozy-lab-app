# G07：确认预约后的提醒入口

本项已核对。旧 `reminder-unavailable-*` 图是 `supportsSessionAutoRefresh=false` 且未提供通知协调器的测试分支，不能代表默认生产构建的提醒入口。默认 App 在启用会话自动刷新时创建 NotificationCoordinator；本轮显式提供同一生产协调器，权限／推送／HTTP 使用隔离替身。

实际链：More → Me → 预约咨询 → 预约前确认 → 选择时间 → 勾选提前 15 分钟提醒 → 确认预约。预约已保存后显示 Receive reminders?；Continue 后替身拒绝权限，进入信息采集；返回预约页，提醒关闭。再次开启显示 Notifications are off；Open settings 调用平台设置，但提醒不会自动变为开启。模拟系统授权恢复并刷新协调器后，再次开启，接口保存成功且预约页显示开启。

| 界面／操作 | 证据 |
| --- | --- |
| 授权说明 | [已有同一弹窗](../07-me/notification-permission-current-education-dialog/README.md) |
| 拒绝后设置引导 | [已有同一弹窗](../07-me/notification-permission-current-offer-settings-dialog/README.md) |
| 预约仍保留，提醒已开启 | [本轮完整图](../raw/test/goldens/ui_inventory/booking-resume-current-configured-reminder-enabled-393-1x.png) · [真实链与元数据](../08-expert-service/booking-resume-current-configured-reminder-enabled/README.md) |

权限说明、协调器及权限控制器的源码指纹与 [已有权限报告](NOTIFICATION-PERMISSION-CURRENT.md) 一致。两个共享弹窗直接引用原图，不复制不同宿主背景的组合；只新增一张当前预约结果图。未重新遍历所有权限错误。

- [严格验证](runs/20260914T081917-booking-reminder-current/capture.log)：1 条配置入口链通过，未更新基线；[静态分析](runs/20260914T081917-booking-reminder-current/analyze.log) 通过。
- [图片与源码记录](runs/20260914T081917-booking-reminder-current/g07-audit.json)：结果图完整，不需长图。
- 本轮通知消息回调为空，未采集 Toast；对应提示沿用已有权限证据。Open settings 仅证明平台调用，模拟授权后直接刷新对应 App 恢复处理，不声称实际操作系统设置或真实推送已验收；系统层继续归 G10。
- 测试传输层复用既有通知 fixture，并将本预约 ID 映射到该 fixture 的提醒记录；没有操作真实预约、设备权限或远程注册。
