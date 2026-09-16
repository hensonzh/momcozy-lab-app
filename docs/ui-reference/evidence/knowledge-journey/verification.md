# 每日知识 → Cozymate 复核

日期：2026-09-12。范围：用户 App 的 `mom/state-02`、`agent/state-03`；这两个状态复用已登记的知识弹窗和 Agent 页面，不增加另一套 UI。

## 设计依据

重新核对当前设计工程 `src/pages/UserApp.tsx` 的 `DailyKnowledgeModal`、Me 页 `onAsk` 和 `AgentPage`，并查看 `mom/knowledge-viewport.png`、`agent/home-viewport.png` 以及旧 `agent/reference/state-03.png`。旧图保留为历史结构参考，当前源码和新版参考图优先。

弹窗保持底部浅色卡片、标题与关闭入口、文章标题与摘要、带序号的要点、说明和带头像的主按钮。原始设计点击按钮关闭弹窗并进入 Agent；App 保留现有业务行为，额外预填当前文章标题，不自动发送。

## 实际验证

使用当前普通 local App（1.0.0+57），Android emulator-5554，已登录 Mia。未安装测试替身，未发送 Agent 问题。

1. Me 页打开当日知识“恢复不是直线，变化本身也值得被看见”。实际弹窗全部内容可读，底部按钮未被系统区域遮挡。
2. 点击“问问 Cozymate”后弹窗消失，进入 Cozymate，输入框内容与文章标题一致；没有出现该标题的用户消息气泡。
3. 点击底部 Me 返回，页面仍显示 Mia；重新打开文章后点击关闭，正确回到 Me。

截图与 UI XML：`native-home`、`native-article`、`native-agent-prefill`、`native-return`、`native-closed`。逐张核对了文章与跳转截图。原设计知识示例为泌乳主题，当前账号按日期显示恢复主题；主题差异未改动文章选择逻辑。

## 回归

- `regression.log`：知识弹窗在 320/390/430 宽度、1/2 倍字号，以及路由壳契约，共 16 项通过。
- `prefill-test.log`：补充可观测的请求客户端断言，确认初始预填文本未发起请求，1 项通过。
- 本轮只修改测试与验收记录，普通 App 二进制沿用此前已构建和验证的版本；无需重建。

## 边界

这里只完成知识入口、弹窗和进入 Agent 的状态验收。当前本地 Agent 仍显示初始介绍，语音服务返回不可用，历史能力未开启；Agent 首页、错误及对话整体状态的待复核项继续保留。未将本次跳转成功视为远端模型、历史服务或语音播放成功。
