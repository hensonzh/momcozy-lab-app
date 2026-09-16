# 妈妈记录、聊天、日程、咨询、媒体及共享浮层最终对照

剩余 9 个页面的 70 条状态、22 类浮层的 103 条状态，共 173 条已完成现有设计、实现、行为和范围对照。没有新增页面、源图或截图组合。逐条依据见 [状态记录](remaining-state-evidence.json)，沿用原始状态名、源图和操作边界。

## 设计及当前实现

[230 个 Figma 引用](remaining-live-figma.json)全部在线可访问；[191 张不同源图](remaining-source-images.json)均存在。交付中保留 Figma 初始设计、最终调整、导出、实现差异及测试。状态记录指向相应交付，不把共用状态、返回目的页或系统窗口当成独立页面重新设计。

| 范围 | 实现与验证依据 |
| --- | --- |
| 妈妈首页、身体／休息／心情 | 批准的 19:2、88:2、88:111 与原交付；mother-diary 的字段绑定、保存及冲突对比；当前 75 项记录／共享组件回归包含妈妈页及日记。冲突确认后更新服务器备注，取消保留草稿。 |
| 泌乳 | lactation 的 177 张运行图与 94 项最终联合检查；7／30 天趋势、缺日和零值、泵奶／亲喂、删除／撤销及未知保存结果保留原意义。3 个生产文件匹配归档。 |
| Cozymate | conversation、history、attachments-menus、reading-cards、form-dialogs、actions-results、voice-notices 七份交付。核对会话恢复、原请求标识、复制菜单返回、表单 schema 和草稿、行动确认／拒绝、附件失败与语音生命周期。最终实现匹配后续归档；当前路由和 Markdown 回归通过。 |
| 日程 | schedule 交付、11 项行为对比、77 项最终联合检查；真实月历／日期／服务期筛选、任务状态、预约入口、保存幂等与冲突恢复不变。沿用原 API 的列表范围，不新增分页功能。 |
| 咨询及总结 | entry、preparation、preflight、live-room、outcomes、summary 交付及 consultation-current-review。设备请求一次、晚到轨道释放、授权版本、入场校验、离开恢复、六类结束结果、任务版本和发布状态分别有断言。当前离开恢复与目的页路由回归通过。 |
| 图片、PDF、视频 | media-viewer 与 media-controls；图片即时失败恢复、缩放／拖动，真实本地 PDFium 两页翻页／缩放，视频平台命令及全屏返回。播放器生产版本匹配归档，当前播放器测试通过。 |
| 宝宝资料及共享控件 | baby-profile、baby-home、baby-records、booking、notifications 等既有交付；资料控制器仍与重构前 SHA 一致，当前资料／知识／切换测试通过。日期、放弃、提示使用原行为与局部主题。 |

## 验证记录与版本差异

- [运行图完整性](remaining-artifact-integrity.json)检查 1,134 条当前图像记录，1,127 条与相关早期归档一致；7 条差异见 [明确处置](remaining-image-version-resolutions.json)。另 3 张普通日历图为带当日标记的历史预览，原交付已说明不纳入固定像素基准。
- 7 条差异涉及聊天头像完成解码、后续宝宝首页背景及聊天列表文字渲染。已比较普通窄屏前后图，并由当前测试验证所对应宽度；没有将旧归档改写成当前版本。
- [当前记录／共享组件 75 项](records-shared-current-tests.log)与[差异图对应 24 项](changed-image-current-tests.log)全部通过，均未更新基准。前者包含日记、妈妈页、资料和知识，后者包含聊天和切换至资料。新增 [18 个当前文件指纹](records-shared-current-fingerprints.json)不冒充缺失的历史指纹。
- 既有 [142 个文件版本审计](implementation-version-audit.json)本轮复查无新变化；6 个测试版本差异已有[处理记录](test-version-resolutions.json)，对应当前回归已通过。各阶段最终日志与行为检查在逐条状态记录中列出，历史联合测试存在重合，不相加成独立测试总数。
- [11 个接收文件](accepted-input-final-check.json)与 Session A 完成交接时一致，包括 manifest。此轮没有运行 inventory 采集测试。

## 明确保留的范围

- 系统键盘、相册／文件、通知、相机、麦克风、设置窗口保持平台外观；Figma 引用代表 App 入口或解释界面，不声称重画 OS 窗口。原有 Android 原生证据保留。
- 全屏视频控件常驻；原清单中的“控件显示与隐藏”只验收现有显示行为，未制造不存在的隐藏状态。视频命令测试使用受控平台，不等于真机解码、真人通话或上线验收。
- knowledge 在宝宝首页可用；妈妈页按批准基准已移除旧知识入口。baby-saved 在首页使用自定义反馈，历史页刷新后使用原 SnackBar。逐条保留宿主区别。
- AI 分析无适配器时仍明确不可用；专家身份、日期、价格、服务状态来自原业务数据。UI 交付不声称新增后端能力。
- 无入口动作评估的缺图状态继续按原范围不适用；失败恢复图不等于成功评估。这一处置见 special-pages 交付。

这些结论建立在已有 Figma-first 交付、当前版本、图像和行为证据之上；不是仅因建立状态关联而判定通过，也不宣称逐一重放 Session A 的每条原始操作链。
