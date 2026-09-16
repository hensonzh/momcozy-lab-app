# G01：当前咨询结束页面补图与入口核对

**本项已完成（本报告记录的源码版本）**。6 种不同结果界面已沿真实 App 路由采集，11 个可见 CTA 均实际点击并验证去向。未扩展屏幕尺寸、字号、HTTP 状态码或时序组合。

入口：已登录 More → Me → 专家陪伴计划 → 查看我的服务 → 开始预约 → 咨询前准备；除未出席外，继续完成设备检查并确认进入咨询室，再接收对应结束状态。未出席在准备页等待到达出席截止时间，不伪造已加入通话。

使用正式 MomCozyFlutterApp、路由、控制器及服务编解码；HTTP 数据和原生设备通道隔离，音视频为 sandbox。结束数据由测试传输层返回，证明 App 当前支持的渲染与操作，不表示真实专家结束了咨询或生产后端已验收。

## 6 个确有差异的页面状态

| 状态 | 当前完整图与操作轨迹 | 可见按钮 → 实际去向 |
| --- | --- | --- |
| 技术失败 | [完整图](../08-expert-service/consultation-journey-current-technical-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-technical-outcome/README.md) | 重新预约 → `/services/episodes/service-episode/booking`；返回妈妈主页 → `/me` |
| 未出席 | [完整图](../08-expert-service/consultation-journey-current-no-show-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-no-show-outcome/README.md) | 重新预约 → `/services/episodes/service-episode/booking`；返回妈妈主页 → `/me` |
| 安全升级 | [完整图](../08-expert-service/consultation-journey-current-safety-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-safety-outcome/README.md) | 查看咨询总结 → `/services/appointments/service-appointment/summary`；重新预约 → `/services/episodes/service-episode/booking` |
| 正常结束 | [完整图](../08-expert-service/consultation-journey-current-completed-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-completed-outcome/README.md) | 查看咨询总结 → `/services/appointments/service-appointment/summary` |
| 已取消 | [完整图](../08-expert-service/consultation-journey-current-cancelled-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-cancelled-outcome/README.md) | 查看咨询总结 → `/services/appointments/service-appointment/summary`；重新预约 → `/services/episodes/service-episode/booking` |
| 结束原因尚未返回 | [完整图](../08-expert-service/consultation-journey-current-pending-record-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-pending-record-outcome/README.md) | 查看咨询总结 → `/services/appointments/service-appointment/summary`；重新预约 → `/services/episodes/service-episode/booking` |

6 张结果图在 393 × 844 下均无纵向溢出；已目视核对从标题、结果说明与按钮直到“本次预约”的时间、时区和专家信息全部可见，因此这些状态不需要拼接长图。正常结束只有“查看咨询总结”；结束原因尚未返回仍显示“重新预约”，故单独保留，不能与正常结束合并。

## 共享入口与跳转目标

同样的目标界面保留代表图；每个按钮的实际运行记录仍分别保存。

- [完成设备检查后的咨询室](../08-expert-service/consultation-journey-current-before-outcome/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-before-outcome/README.md)
- [重新预约：预约前确认浮层](../08-expert-service/consultation-journey-current-outcome-rebook/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-outcome-rebook/README.md)
- [返回妈妈首页：完整长图](../08-expert-service/consultation-journey-current-outcome-home/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-outcome-home/README.md)
- [查看咨询总结：待发布](../08-expert-service/consultation-journey-current-outcome-summary/default.png) · [入口及轨迹](../08-expert-service/consultation-journey-current-outcome-summary/README.md)

首页长图已实际滚动到页面底部，覆盖我的陪伴计划与底部导航；其余 3 张无纵向溢出。结果说明、不同图标、按钮数和下一步关系均保留。

## 验证与复用边界

- [严格截图比较日志](runs/20260914T072616-outcome-current/capture.log)：11 项实际按钮链通过，10 个截图条目。
- [源码快照](runs/20260914T072616-outcome-current/source-snapshot.json)中本批渲染组件及测试文件与当前一致；Agent 对话面板及其设计测试在采集后另有修改，但未挂载于本批 10 张画面，已在审计中单列；[静态分析](runs/20260914T072616-outcome-current/analyze.log)无问题。
- [逐图范围与按钮去向审计](runs/20260914T072616-outcome-current/g01-audit.json)。
- 已有改版目录的 6 张图继续作为尺寸/字号参考，未重复重采该矩阵；本次补齐的是原清单缺少的当前正式入口和完整页面证据。
- 本项不代替 G02 通话/离开状态、G03 总结页全部状态，也不代替原生权限和真实音视频验收。
