# G11：Agent 版本差异与现有证据复用

此前批次的失败已定位并解决；不重跑 Agent 全部组合。当前差异分为 Markdown、行动面板和表单，其余已通过场景按源码边界复用。原批次仍记为 10 通过、1 失败，不改写历史结果。

## Markdown：复用原图，补齐采集等待

0.68%／2253 像素的差异全部位于聊天头像和底部头像，正文、标题、链接、列表和布局没有差异。原因是独立运行时资源解码未完成。仅在采集 helper 中等待现有本地头像加载，随后 390／1× 的原场景严格通过，未更新任何 Markdown 金图。

[首屏](../raw/test/goldens/design_system/agent-markdown-top-390-1x.png)与[链接窗口](../raw/test/goldens/design_system/agent-markdown-link-390-1x.png)均为完整视口，元数据没有纵向溢出；外部链接点击回调也由原场景验证。[本次严格运行](runs/20260914T091638-g11-agent-markdown/capture.log) · [静态分析](runs/20260914T091638-g11-agent-markdown/analyze.log)。

## 其它界面：按已发生的实际变化归并

| 范围 | 当前证据 | 复用依据及边界 |
| --- | --- | --- |
| 附件提示、语音状态、普通卡片及通知进入指定会话 | [此前定向批次](runs/20260914T090104-g11-agent-drift/capture.log)，[G08 入口与历史抽屉](AGENT-ENTRY-CURRENT.md) | 当前行动改版前的完整 AgentHub 文件与此前批次的源码哈希完全一致；改版后除结果卡 import 与 AgentActionPanel 外，其前后全部代码逐字一致。上述测试没有构造行动面板；产品路由及结果卡／资源注册／artifact 面板源码也与该批次一致 |
| 行动确认、拒绝、等待、失败及结果 | [当前交付](../../ui-refactor/20260914-agent-actions-results/HANDOFF.md) · [逐态表](../../ui-refactor/20260914-agent-actions-results/coverage.json) · [验证图](../../ui-refactor/20260914-agent-actions-results/verified-images.json) | 本次核对该交付 4 个源码／测试指纹全部匹配，引用已交付 96 张变体图和实际操作验证，不重新采集这些组合 |
| 表单输入、校验、提交与只读 | [当前交付](../../ui-refactor/20260914-agent-form-dialogs/HANDOFF.md) · [逐态表](../../ui-refactor/20260914-agent-form-dialogs/coverage.json) · [验证图](../../ui-refactor/20260914-agent-form-dialogs/verified-images.json) | 本次核对该交付 6 个指纹全部匹配，引用 72 张已有变体图。此前旧表单图不能替代这份当前交付 |
| 历史抽屉 | [G08 完整图与入口](AGENT-ENTRY-CURRENT.md) · [组件交付](../../ui-refactor/20260914-agent-history/HANDOFF.md) | 2 个组件／测试指纹匹配；仍保留普通首页与指定会话不同启用条件及既有长图 |

[可复查的源码边界、哈希及既有图片列表](runs/20260914T091638-g11-agent-markdown/reuse-audit.json)。只关闭 G11 具名版本差异，不将这些组件报告当成全 App 状态验收。

行动交付中提到的两类记录详情“尚未新版设计验收”，属于另一个改版任务；本 UI 盘点应保留当前实际详情页面及入口证据，不能据此虚构新页面或要求重新设计。PDF、视频和记录详情仍在各自页面清单中最终对应。
