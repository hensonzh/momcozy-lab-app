# 用户视频等待室与离开确认

2026-09-12。此次完成范围为 state-53 等待专家状态、room-leave 离开确认。整个 services/room 仍待继续验收真实视频与结束结果。

## 设计依据

重新查看原 state-53 长图，并读取当前 UserApp.tsx VideoPage 3730–3810 行、CSS 411–436、865–899、2679–2690 行。重新在隔离浏览器完成预约、采集、设备确认和入室，捕获 `services/state-53-viewport.png` 与 `services/room-leave-viewport.png`，来源见 capture-manifest.json。设计端为受控模拟服务及 getUserMedia，不访问 API / 外部网络，不代表真实视频连接。

当前设计为返回标题栏、单张带圆角和阴影的咨询卡片。卡片内连续排列专家与时间、状态标签、深色视频舞台、自己的小画面和三项控件。离开确认为底部弹窗，保留当前设计的 86vh / 660 高度上限，固定标题、用途说明、留在房间和暂时离开；大字号时操作纵向排列并可滚动。

## 实现与真实数据

用户 RoomPage 采用整体卡片；摘要紧凑布局，标准字号状态标签在右侧，放大字号移到摘要下方。视频舞台复用既有未静音 LiveKit 轨道选择和 VideoTrackRenderer，用户渲染在 UserConsultationVideoStage 中；工作台仍使用原舞台与控件参数，不改其准备、结束和专家操作。

等待专家、专家已进入、双方已开始但专家摄像头关闭、对方重连／暂时离开、自己连接中／重连／断开均沿用真实 media state 与 participant presence。舞台角标只说明媒体连接或模拟环境，不输出服务商内部调试名。既有 API 不含专家头像 URL，故以实际姓名缩写显示，不使用 Jamie Lee 示例照片。自己的画面显示真实本地轨道；未开摄像头显示关闭图标，没有轨道时不伪造摄像头画面。

麦克风、摄像头仍调用原媒体 API，在连接中、重连、模拟媒体或媒体忙碌时禁用。操作加可辨识的禁用语义；离开控件使用设计中的低强调箭头，离开确认明确不会结束咨询。确认调用原 leave/disconnect；取消确认保留连接；不调用专家 end 接口。弱网、媒体失败及音频播放受限提示集中在卡片内，仍保留启用声音和断开后的重连／返回准备入口。

ProductFlowDialog 的可选 minHeight 只在离开确认使用，并与 maxHeight 和可用屏高共同限制，默认值为 0，其它流程保持原高度策略。

## 验证

新增 6 项三宽 × 1x/2x 字号页面流程测试：等待、切换麦克风／摄像头、忙碌时不重复调用、专家到场、摄像头关闭占位、重连禁用、媒体错误和弱网、启用音频、取消离开、确认离开。断言媒体调用计数、连接状态以及 endCalls 为 0。现有等待室、授权、设备、结束和工作台测试一并通过。

实际 Flutter 图为 `test/goldens/design_system/video-{waiting,expert-ready,camera-off,reconnecting,media-error,leave}-*.png`。正常 390 与 320 大字号均已查看；大字号通过滚动触达底部控件并完成离开。已有 product_baseline/room-waiting 系列同步更新。截图等待 300ms 样式过渡，避免把尚未完成的绘制状态作参考。

整合回归结果见 regression.log，静态分析见 analyze.log，普通本地 APK 构建与安装见 build.json / build.log。native-restored-home 仅证明安装后 Mia 登录与主页正常，不作为视频端到端截图。

本轮仓储与媒体状态为测试输入，没有远程视频轨道、真实服务订单／预约或双端连接。真实远程画面、服务端重连和结束交接仍由 services/room 保持 Need Review，不能将控件回调通过表述为真实视频 E2E 成功。
