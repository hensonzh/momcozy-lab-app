# 首页预约准备弹窗

2026-09-12，仅用户 App；mom/state-43。

## 设计与实现

重新读取 UserApp.tsx HomeConsultPreparation（554–585）、首页已填表动作（1003–1017）与预约详情弹窗（1041），以及 me-agent.css 6–16、184 和 styles.css 1110–1131。重新捕获当前浏览器准备弹窗（mom/home-preparation-{viewport,full}.png）。全部 API 和外域请求被阻断；只在独立浏览器中构造未来的已确认预约，没有创建真实预约。

已填表首页卡的“查看预约”现在直接打开居中准备弹窗，保留首页背景。home_consultation_dialog.dart 复用 ConsultationRoomPage、ConsultationPreparation 和原有 RoomController；进入咨询后由同一控制器和媒体实例呈现完整咨询室。独立 room 路由继续使用相同准备内容，通知等来源的预约详情页仍保留原路径。没有新增 Backend/API、付款或预约契约。

ProductFlowDialog.expert 采用 360 最大宽、18 圆角、19 标题、expertSurface/expertBorder、关闭图标与 #202b3155 遮罩。内容可滚动，字号放大后按钮纵排。预约日期使用其时区；倒计时、开放时间、资料/授权及服务可用性仍读取既有服务端上下文。设计中的 California 演示提示没有替代真实地区校验，演示模式也没有变成生产早入场条件。

进入取消确认或设备检测后，准备面板先隐藏，避免两个表单叠在一起。保留/取消预约均收起弹窗返回首页，首页原有回调重新读取服务状态。取消动作继续复用现有版本校验和结果不确定时的核对流程。视频设备、位置与授权确认继续复用原有流程；关闭设备/入场确认回到首页，连接成功后保留咨询室。

修复嵌套跳转：从入场确认跳转信息采集时，必须先关闭其子弹窗及首页准备弹窗，再将 intake 去向交回首页路由。nested-before.log 记录修复前返回值为空、首页遮罩残留的失败；对应回归已通过。用户忙碌时的返回保护仅作用于用户流程，IBCLC 分支不变。

## 验证

- 新增 8 项 widget 测试：加载中关闭后无残留轮询、失败重试、嵌套信息采集跳转，以及 320/390/430 × 1x/2x 的真实服务卡→准备→关闭/取消确认→设备检测→位置确认→等待室→留在房间/离开→取消预约。测试检查点击可达、版本参数、单次 join、媒体连接与离开、返回次数。
- 18 张 home-preparation-{ready,cancel,room} 图像基线；已目视核对普通字号和 320/2x 准备、取消确认、全屏等待室。独立准备页与入场流程的相关金图同步更新，通用弹窗的默认样式不变。
- 最终咨询、服务及路由回归 268 项通过；静态分析无问题。
- Android integration_test/home_consultation_dialog_test.dart 1 项通过，覆盖普通字号与两倍字号打开、关闭、再次打开，真实截图为 native-home-preparation-1x/2x.png。宿主只挂载生产弹窗，以 canonical room_context.json 的内存仓储替身读取，未连接 API、未申请设备权限、未创建咨询或写入账号。它证明原生渲染与弹窗生命周期，不代表真实后端预约/远程音视频端到端通过。

run-native.py 使用 --no-uninstall 保留登录数据，以 base64 dart-define 传入原有 JSON fixture；截取 Android 文档目录内生成的 PNG 后，重新构建安装普通 local debug APK。完整真实预约链路与远程视频仍在 services/room 待复核。

常规调试包恢复后，native-restored-home.png/XML 已确认登录身份为 Mia；本次没有改变账号、日记、泌乳数据或设备权限。
