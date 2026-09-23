# G08：当前指定会话入口与历史抽屉

> 2026-09-20 一期范围更新：会话历史管理、新建会话和消息长按菜单已删除；指定会话仅加载正文。下文截图和入口描述为历史版本记录。


本项已核对。旧 [初始化异常报告](AGENT-TARGET-ENTRY.md) 只代表旧版本；当前 `momcozy_app.dart` 已以稳定 Object 身份保存会话缓存键，通知进入指定会话不再出现字符串 Expando 错误。本轮未修改产品代码。

## 当前入口条件

- 普通 `/` 且默认历史能力关闭：不提供历史仓库，普通首页不出现历史按钮。
- 通知进入 `/?conversationId=…`：即使全局历史能力关闭，也提供仓库、加载指定会话并显示历史按钮。
- 全局 `MOMCOZY_ENABLE_AGENT_HISTORY=true`：普通首页也可用历史。这是既有能力配置，不为默认构建强行开启。

现有真实路由测试从通知列表点击 Service update 1，通知标记已读，指定会话历史接口实际由隔离 HTTP 返回，生产 Agent 页面正常显示内容。长按消息后系统返回关闭菜单并保留会话。本轮再实际点击历史按钮，验证列表包含两条会话，点击关闭回到指定会话；抽屉视觉复用下表，不新增一套不同背景截图。

原有场景还验证不同 thread 的草稿隔离、切换后草稿恢复，以及新 runtime 不复用上一登录的草稿。直接 `router.go` 的后续隔离断言仅作状态验证，不冒充通知点击路径。

## 代表图

| 状态 | 完整图 | 来源 |
| --- | --- | --- |
| 无历史会话 | [图](../raw/test/goldens/design_system/agent-history-empty-390-1x.png) · [索引](../05-agent/agent-history-empty/README.md) | 已有抽屉场景 |
| 历史列表含当前标记 | [图](../raw/test/goldens/design_system/agent-history-list-390-1x.long.png) · [索引](../05-agent/agent-history-list/README.md) | 已有抽屉场景 |
| 列表末尾（同页完整图归并） | [图](../raw/test/goldens/design_system/agent-history-list-end-390-1x.long.png) · [索引](../05-agent/agent-history-list-end/README.md) | 已有抽屉场景 |
| 加载错误与重试 | [图](../raw/test/goldens/design_system/agent-history-load-error-390-1x.png) · [索引](../05-agent/agent-history-load-error/README.md) | 已有抽屉场景 |
| 首次加载 | [图](../raw/test/goldens/design_system/agent-history-loading-390-1x.png) · [索引](../05-agent/agent-history-loading/README.md) | 已有抽屉场景 |
| 回复期间锁定切换 | [图](../raw/test/goldens/design_system/agent-history-locked-390-1x.long.png) · [索引](../05-agent/agent-history-locked/README.md) | 已有抽屉场景 |
| 切换失败 | [图](../raw/test/goldens/design_system/agent-history-switch-error-390-1x.long.png) · [索引](../05-agent/agent-history-switch-error/README.md) | 已有抽屉场景 |
| 切换中 | [图](../raw/test/goldens/design_system/agent-history-switching-390-1x.long.png) · [索引](../05-agent/agent-history-switching/README.md) | 已有抽屉场景 |
| 通知打开指定会话后的实际页面 | [图](../raw/test/goldens/design_system/notification-conversation-393-1x.png) · [索引](../10-global-modals/notification-conversation/README.md) | 真实通知入口 |

9 张完整图已核对，其中 5 张长图覆盖全部列表和状态提示；list 与 list-end 的同页完整图统一归并，原滚动窗口保留。没有重跑尺寸／字号矩阵。

- [2 个既有定向场景严格验证](runs/20260914T081744-agent-entry-current/capture.log)：通过，未更新原金图。首次附加检查曾误认指定会话也无历史按钮，实际运行发现按钮存在；按产品仓库条件修正断言并验证打开、读取和关闭。
- [静态分析](runs/20260914T081744-agent-entry-current/analyze.log)、[逐图与相关源码记录](runs/20260914T081744-agent-entry-current/g08-audit.json)。
- 历史抽屉的空、加载、错误、锁定、切换图来自生产组件与隔离仓储；只有指定会话图及新增入口断言属于实际 App 路由证据。没有声称真实用户会话或网络服务已验收。
- 全 App 的其它 Agent 状态和历史源码版本仍按 G11 核对，不扩展本项为聊天全功能矩阵。
