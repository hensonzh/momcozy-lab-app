# 视频咨询：未开始与技术故障后的去向

范围：用户 App 的两个异常结束状态。`services/room` 仍为 Need Review，不能据此认为音视频及咨询后 AI 衔接全部完成。

## 参考与实现

修改前重新读取设计 `src/pages/UserApp.tsx` 的 VideoPage（3730–3810），以及 `styles.css` 的 video-state-card、video-state-icon、btn、h2。设计明确要求未到场与技术故障优先重新预约，其次返回妈妈主页；此前 App 将查看咨询总结置于首位。

本目录 design-user_no_show.png、design-technical_failure.png 为当前原稿的独立截图，捕获过程见 design-captures.json。使用隔离浏览器内的演示数据，屏蔽所有 API 和外部请求，没有创建真实预约。

`ConsultationRoomPage` 仅在用户角色、已有结束状态且 endReason 为 userNoShow / technicalFailure 时显示新的恢复卡片。主按钮携带原 appointment 进入该服务的预约流程；返回妈妈主页明确进入 `/me`，不依赖导航栈。保留既有次数说明，无新增扣费或咨询结束请求。专家工作台及其他结束原因保留原分支。

视觉复用公共 Card、标题、正文行高、颜色和服务按钮规范；加入时钟/断网图标，主按钮按内容宽度显示，次操作为灰色文字。原稿 42px 按钮提高为最小 44px 触控区域；正文及标题正常缩放，小屏允许滚动。没有加入新设计版本或后端字段。

## 验证

- 320 / 390 / 430 宽度，1x / 2x 字号：6 个场景测试，12 张 Flutter 截图。两种状态均验证重新预约、返回主页、预约 ID 保持、无总结操作、无入会与结束请求。
- 咨询模块及路由契约共 101 项测试通过（regression.log）。首次命令误包含不存在的 mom_module_routes_test.dart，已改为实际存在的 momcozy_route_shell_contract_test.dart；错误命令输出保留为 regression-initial.log。
- 5 个修改及新增 Dart 文件静态分析通过（analyze.log）。
- Android 相同页面及控制器，真实原生渲染和点击：1x / 2x，4 张 native-room-*.png；native.log 通过。受控仓储采用项目既有 room_context.json 结构，未连接真实咨询服务，也未验证真实扣费、远端音视频或再次预约写入。
- 目视对比原稿及实际截图后，将原先全宽主按钮收紧为内容宽度、技术故障图标改为断网，并重复上述回归与原生验证。
- 普通本地 Debug APK 已重新构建并安装，模拟器恢复到 Mia 的妈妈主页；见 build.log、install.log、native-restored-home.png / .xml。测试入口未留在模拟器中。

## 尚未解决

正常咨询结束时，原稿会先断开音视频，再进入 Cozymate，并发送隐藏的咨询衔接请求（postconsult / consultationAppointmentId）。当前 App、Agent 与 Backend 没有对应上下文契约，仍进入既有总结查看流程；不能让 AI 声称已读取专家发布结果。此项单独保留，不制造请求字段或虚构咨询结论。

后续已复现并修复 disconnect 抛错后无法重试的问题，含连接上报顺序与提示可见性验证，见 [离开失败恢复](../room-leave-recovery/verification.md)。
