# 服务进度时间线

2026-09-12，用户 App。

## 设计与实现

开始前重新读取 `source/src/pages/UserApp.tsx` 的 ServiceProgressPage、`source/src/components/MeOverview.tsx` 的 MeServiceTimeline 和 `source/src/styles/me-service-progress.css`。重新捕获 `services/progress-viewport.png`、`services/progress-full.png`；长图展开设计工程内部滚动容器。浏览器使用隔离 demo 状态，屏蔽所有 API 和外部请求；设计示例历史不作为真实服务数据使用。

原生页面改为紧凑标题栏、固定服务身份区、服务次数与时长、完整时间线、较早记录入口及回到最近记录的悬浮按钮。默认定位最近记录。卡片使用 12 圆角、蓝灰时间轴、最近记录描边，色值沉淀到共享 Design System。正常字号保留左侧日期，大字号将日期放入卡片内，时长移到服务名称下方；已修正大字号返回文字换行。

原生订单和预约数据决定内容：展示当前 episode 全部预约并按 startsAt 排序；过滤 held 和其他 episode，取消和过期记录保留但无进入按钮。已完成进入总结，其他有效预约保留原有进入路径。预约日期和时间使用该预约的 timezone。服务身份使用最近未取消、未过期预约的真实专家名称；API 没有头像 URL，因此使用姓名缩写，无专家时显示团队图标，不借用示例专家照片。

次数使用已购买服务 episode 的 totalSessions / remainingSessions，时长使用原订单，避免用可能变化的商品目录代替已购买额度。保留服务器 canBook 允许时的“预约咨询”入口，设计时间线原稿没有该底部入口；这是保留既有功能的明确差异。没有加入设计 demoServiceHistory 或伪造的历史记录。

预约读取从 build 中移到生命周期与刷新流程，解决原实现只加载一次且只显示最后一个预约的问题。下拉刷新重新读取预约；失败保留已知服务信息并显示重试。请求返回使用 generation 和 mounted 防止过期响应、离开后更新。订单或商品关联缺失显示可返回的空状态，避免原先 first 查找异常。

## 验证

`test/modules/services/service_progress_test.dart` 新增 15 项：320/390/430 宽度、1x/2x 字号；查看较早和最近记录；每条预约各自打开；读取失败后重试；刷新更换记录；五种服务状态控制预约入口；320×568 双倍字号；请求未完成离开；无服务空状态。既有 service_design_test 的预约入口用例继续通过。

实际 Flutter 渲染基线见 `test/goldens/design_system/progress-{latest,earlier,offline,empty,loading,short}-*.png`。目视对比了 390 时间线、320 大字号、短屏大字号和离线状态。新版大字号日期移入卡片，服务信息换行，内容可滚动，导航和操作文字无裁切。

最终整合回归 294 项通过（服务、咨询、通知、文档页面及控制器、路由）；flutter analyze 无问题。详见 regression.log、focused.log、analyze.log。普通本地 APK 构建记录见 build.json 和 build.log。

本地后端没有有效服务订单与预约，完整历史使用受控仓储验证；原生模拟器只验证实际构建启动和无服务分支，不宣称真实购买、专家咨询或服务完成端到端通过。

## 相邻页面盘点纠正

RenewPage：后续已补齐独立继续支持页面和入口，验收见 ../renew/verification.md。
SelfManagementPage：没有独立路由，“保存下一步”没有已确认的原生保存契约，仍待实现。
ReferralPage：没有独立路由或已接入的转介请求仓储。设计只是浏览器内存提交演示，不可据此显示真实“请求已记录”。
这三项此前全部指向 ServiceProgressPage，现已纠正；续购已独立验收，自主管理与转介仍待实现。

原生验证：普通 APK 构建耗时 9.3 秒、安装成功。冷启动 `/services/episodes/ui-missing-service` 显示真实无服务提示，点击“返回妈妈主页”回到 Mia（产后第 21 天）主页；截图与 UI 树见 native-empty 和 native-restored-home。没有修改测试账户服务数据。
