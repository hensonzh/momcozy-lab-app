# G02：当前通话页、离开确认与失败反馈

**本项已完成（本报告记录的源码版本）**。以一个标准尺寸沿实际 App 路由核对离开和重新入室；复用现有媒体状态金图，仅补实际缺失的界面。3 项定向场景通过，没有扩展尺寸、字号或故障组合。

本轮保留 16 个窗口证据：复用并严格匹配 11 张已有金图，新增 4 张当前路由图，以及 1 张开启通话声音后的状态图。相同页面的同像素图仍在总清单归并；原有 320/430 宽度和 2× 字号参考保留，没有重跑该矩阵。

## 实际 App 入口与离开链

已登录 More → Me → 专家陪伴计划 → 查看我的服务 → 开始预约 → 咨询前准备 → 设备检测 → 确认进入。等待页复用 [G01 实际入室图](../08-expert-service/consultation-journey-current-before-outcome/default.png)。

| 操作 | 完整画面与操作轨迹 | 核对结果 |
| --- | --- | --- |
| 离开房间 | [图](../08-expert-service/consultation-journey-current-live-leave-confirmation/default.png) · [轨迹](../08-expert-service/consultation-journey-current-live-leave-confirmation/README.md) | 显示确认；留在房间与右上角关闭均保持原连接 |
| 留在房间／关闭确认 → 专家加入 | [图](../08-expert-service/consultation-journey-current-live-active/default.png) · [轨迹](../08-expert-service/consultation-journey-current-live-active/README.md) | 显示咨询中；未创建额外连接 |
| 暂时离开 | [图](../08-expert-service/consultation-journey-current-live-left-booking/default.png) · [轨迹](../08-expert-service/consultation-journey-current-live-left-booking/README.md) | 返回预约详情，报告离线，不结束咨询，保留返回咨询室按钮 |
| 预约详情 → 返回咨询室 | [图](../08-expert-service/consultation-journey-current-live-reentry-preparation/default.png) · [轨迹](../08-expert-service/consultation-journey-current-live-reentry-preparation/README.md) | 显示重新进入咨询室；实际完成检查和入室，新建第二条连接 |

以上使用正式 MomCozyFlutterApp、路由、控制器和服务编解码；HTTP 与设备通道隔离、视频为 sandbox。路由是实际执行的，不把真实服务器或真实远程音视频当作已验证。

## 媒体状态与离开失败的复用图

下列状态实际挂载生产咨询室组件、点击可见控件；媒体故障使用替身触发。它们证明界面与按钮行为，正常入口和离开后的目标由上方 App 链独立证明，不将回调计数升级为真实导航。

| 具名状态 | 当前完整图 | 已验证操作／差异 |
| --- | --- | --- |
| 离开失败 | [完整图](../raw/test/goldens/product_baseline/room-leave-failure-390-1x.png) · [索引](../08-expert-service/room-leave-failure/README.md) | 模拟媒体清理失败，提示可见、房间连接保留 |
| 失败后重试确认 | [完整图](../raw/test/goldens/product_baseline/room-leave-retry-confirmation-390-1x.png) · [索引](../08-expert-service/room-leave-retry-confirmation/README.md) | 重新确认后清理成功；不结束咨询 |
| 咨询中，对方未开启摄像头 | [完整图](../raw/test/goldens/design_system/video-camera-off-390.png) · [索引](../08-expert-service/video-camera-off/README.md) | 专家身份占位 |
| 媒体控制 | [完整图](../raw/test/goldens/design_system/video-controls-390.png) · [索引](../08-expert-service/video-controls/README.md) | 实际点击麦克风、摄像头；忙碌时禁用 |
| 连接中断 | [完整图](../raw/test/goldens/design_system/video-disconnected-390.png) · [索引](../08-expert-service/video-disconnected/README.md) | 显示重新连接与返回咨询准备 |
| 中断后的操作区 | [完整图](../raw/test/goldens/design_system/video-disconnected-actions-390.png) · [索引](../08-expert-service/video-disconnected-actions/README.md) | 实际重新连接；再次中断后点击返回咨询准备 |
| 专家已进入 | [完整图](../raw/test/goldens/design_system/video-expert-ready-390.png) · [索引](../08-expert-service/video-expert-ready/README.md) | 等待专家开始；已静音和摄像头关闭 |
| 媒体异常后的离开确认 | [完整图](../raw/test/goldens/design_system/video-leave-390.png) · [索引](../08-expert-service/video-leave/README.md) | 留在房间不退出；暂时离开触发离开回调 |
| 声音已开启，其他提示保留 | [完整图](../raw/test/goldens/design_system/video-media-audio-enabled-390.png) · [索引](../08-expert-service/video-media-audio-enabled/README.md) | 新增的实际可见差异；开启声音按钮已消失 |
| 摄像头错误、弱网及声音受限 | [完整图](../raw/test/goldens/design_system/video-media-error-390.long.png) · [索引](../08-expert-service/video-media-error/README.md) | 完整长图覆盖提示、开启声音与最后操作区 |
| 正在重连 | [完整图](../raw/test/goldens/design_system/video-reconnecting-390.png) · [索引](../08-expert-service/video-reconnecting/README.md) | 控件禁用，显示恢复连接提示 |
| 等待专家 | [完整图](../raw/test/goldens/design_system/video-waiting-390.png) · [索引](../08-expert-service/video-waiting/README.md) | 媒体已连接、麦克风和摄像头可用 |

16 张完整图均已目视核对。媒体错误页的首屏不足以容纳所有操作，已使用实际纵向滚动拼接的长图；其余本轮标准尺寸画面没有纵向溢出。离开确认、失败提示和重试按钮均完整可见。

“重新连接”与“返回咨询准备”均实际点击；“开启声音”后只补按钮消失这一张有区别的界面。重试离开通过模拟一次本地媒体清理失败验证，不借 HTTP 失败冒充该错误——服务端离线报告失败会被控制器吞掉，不会显示此提示。

## 验证记录与范围

- [采集命令](runs/20260914T073946-live-current/capture-command.json)及[严格比较日志](runs/20260914T073946-live-current/capture.log)：3 项通过。
- [静态分析](runs/20260914T073946-live-current/analyze.log)：修改的 2 个测试文件无问题。
- [逐图审计与操作核对](runs/20260914T073946-live-current/g02-audit.json)、[源码快照](runs/20260914T073946-live-current/source-snapshot.json)：本批渲染组件及相关测试无漂移，其他并行修改单列。
- 尚未验收真实双端视频或系统权限窗口；系统窗口仍归 G10。本项关闭不表示整个咨询模块及全 App 所有状态已完成。
