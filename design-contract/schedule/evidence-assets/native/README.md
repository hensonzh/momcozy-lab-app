# 本地设备安装与检查

- 设备：`emulator-5554`，Android 17 / API 37，1280×2856；本次未检测到实体手机。
- 包：`com.momcozymai.app.flutterpoc.local`，`local debug`，`1.0.0+57`；构建当前工作区（含最新 Schedule 月历箭头字号修正），随后 `adb install -r` 覆盖安装成功，保留账号和数据。安装后更新时间：2026-09-21 07:43:15。
- 产品 API：`http://10.0.2.2:8769`；Agent API：`http://10.0.2.2:8010`。宿主机两端 `/v1/health/ready` 均返回 200。
- 已验证：App 冷启动成功；Schedule 显示真实日程与事件圆点；从 9 月 13 日收起后显示 9 月 7–13 日；新增弹窗覆盖底栏，空标题禁用保存，关闭后回到日程；最新安装后再次确认 Schedule 选中态、`收起日历`、空状态和 `添加日程` 语义节点。未创建、修改或删除验证用数据。
- 截图：[月历](installed-schedule.png)、[所选周](installed-week.png)、[新增](installed-editor.png)、[最后界面](installed-schedule-final.png)。这是设备功能检查，不能代替原有 393×844 的 Figma 同尺寸对比。
- 初次构建的 Maven AAPT2 `9.0.1-14304508` 启动失败；本机 SDK 36.0.0 的 AAPT2 正常。仅在构建命令环境中设置 `ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride` 后重试成功，未修改项目 Gradle 配置。日志见 `build.log` 与 `build-retry.log`。
- 当前 Flutter/Kotlin 插件仍有未来兼容性提示，不影响此次构建。启动默认 Me 页曾显示「加载失败，请重试」；切换 Schedule 后真实数据读取与本次检查正常，Me 的接口/页面问题未在本次安装任务中修复。
- APK 路径、大小、SHA256、源提交基线和资源校验见 [build.json](build.json)。没有公开发布、没有推送或部署后端。本地模拟器构建不增加发布版本号。
