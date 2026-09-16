# Cozymate Markdown 阅读排版

本轮由全局局部样式审计发现：普通助手回复使用 16px / 1.65，但只要包含 Markdown，加粗、列表和链接等内容会进入另一分支，被旧段落样式强制覆盖为 1.42。新增回归在旧实现中失败（before.log）。

## 参考与修正

修改前重读当前设计 UserApp.tsx 的 AgentMarkdownText（2100 起）、styles.css 的 agent-markdown（2093 起及 2719），以及 me-agent.css（302–333）。同一受控文本在隔离的本地设计浏览器渲染，屏蔽 API 与外部请求；设计截图及 computed style 见 design-markdown.png、design-metrics.json。

设计实测正文为 16 / 26.4px，标题为 17 / 25.5px。App Markdown 正文现在保留调用方的 1.65 行高，颜色继承 agentInk；一级至三级 Markdown 标题与设计统一为 17 / 1.5，使用 Manrope。加粗保留正文颜色并采用标题字族，链接恢复紫色及下划线，不再仅靠玫瑰色和粗体区分。

移除标题下重复追加的内边距，保持原生 Markdown 渲染器的 10px 块间距。原生额外支持的代码、表格、引用继续保留；代码使用独立等宽字族及 1.36 行高，不套正文规范。Markdown 解析、链接过滤、附件读取、消息复制及流式协议没有修改。

## 验证

- 同一 AgentHubPage：320 / 390 / 430 宽、1x / 2x 字号，共 6 个测试、12 张截图；检查实际 RichText 叶子继承后的字号、行高和颜色，滚动到链接并验证操作回调。
- 初次 RichText 检查误读了根节点的默认 14px；测试已改为合并父子 TextSpan 样式，检查真正显示文字的叶子，而非放宽设计要求。
- Agent Hub、Agent Stream 与媒体相关共 544 项回归通过，见 regression.log。初轮 9 个截图测试失败来自相同排版变化；人工核对后更新 15 张已有基线（3 张对话、12 张消息菜单），其余既有基线未变，见 golden-changes.json。
- 新增的链接检查仅记录动作对象，不打开示例网站、不发送消息或执行远端 Agent 请求。现有安全链接、原始标记处理、流式 Markdown、图片和文件检查一并通过。
- 5 文件静态分析无问题（analyze.log）。Android 正常/双倍字号下真实页面渲染及链接动作通过，4 张截图见 native-agent-markdown-*.png，结果见 native.log。
- 普通本地 Debug APK 构建、安装成功，模拟器恢复 Mia 妈妈主页；见 build.log、install.log 与 native-restored-home.png / .xml。

## 主题审计仍待处理

本轮未将 common/theme 标为完成。发现首次使用中照片隐私说明、生成阶段说明、长等待说明仍有 1.35 / 1.4 的局部正文覆盖（onboarding_page.dart），需要按已批准的衍生规范复核其阅读密度；标题与控件不能随段落批量替换。登录专用 Libre Caslon、图表数字和等宽代码属于不同角色，不应仅因使用局部字体而删除。
