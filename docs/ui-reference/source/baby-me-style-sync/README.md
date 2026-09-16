# Baby 与 Me 样式对齐 · 2026-09-08

本次为视觉样式统一，以当前本地 Me 为参照，不是流程重设计。仅本地验证，未部署。

## 修改边界

- 保留：页面内容及顺序、记录字段、统计与校验、保存/撤销、宝宝数据隔离、智能体跳转、底部导航。
- 统一：首页留白、标题层级、暖米色/浅桃色圆角卡片、Me 同款紫色智能体 Banner。
- 统一：睡眠、尿湿、便便、喂养、生长记录、切换宝宝与资料弹窗，采用 Me 日记表单的奶油底色、深棕标题与按钮、暖色选中态。
- 保留语义颜色：生长曲线的绿色参考范围、便便颜色选项、错误与成功反馈，不用主题色覆盖这些含义。
- 不涉及：预约或预问诊修复、服务端、真实健康数据写入、新增业务能力。

## 视图索引

| 视图 | 本地截图 |
| --- | --- |
| Baby 首页 | [home-390.png](images/home-390.png) |
| 生长指标与曲线 | [growth-390.png](images/growth-390.png) |
| 睡眠记录 | [睡眠-390.png](images/睡眠-390.png) |
| 尿湿记录 | [尿湿-390.png](images/尿湿-390.png) |
| 便便记录 | [便便-390.png](images/便便-390.png) |
| 喂养记录 | [feeding-390.png](images/feeding-390.png) |
| 生长记录 | [growth-entry-390.png](images/growth-entry-390.png) |
| 喂养校验错误 | [feeding-validation.png](images/feeding-validation.png) |
| 保存与撤销反馈 | [feeding-saved.png](images/feeding-saved.png) |
| 正在睡眠 | [sleep-active.png](images/sleep-active.png) |
| 切换宝宝 | [baby-switcher.png](images/baby-switcher.png) |
| 宝宝资料 | [baby-profile.png](images/baby-profile.png) |
| 智能体知识详情 | [knowledge-article.png](images/knowledge-article.png) |
| 空数据与缺失资料 | [empty-growth-320.png](images/empty-growth-320.png) |
| 长昵称与短屏资料表单 | [profile-short-viewport.png](images/profile-short-viewport.png) |

`before/` 是修改前截图；`me-regression/` 是 Me/Cozymate 回归截图。

## 验证

- 单元测试：最终工作区 118 项通过（执行 `node --test --experimental-strip-types tests/*.test.ts`）。
- `npm run build`：通过；保留既有的大体积 bundle 提醒。
- `node scripts/baby-me-style-smoke.mjs`：通过 320、390、430、1024 px，以及 320×600 短屏检查；涵盖上述视图、错误恢复、保存/撤销、多指标草稿、睡眠开始/结束与切换宝宝。
- `ME_STYLE_OUTPUT=baby-me-style-sync/me-regression node scripts/me-agent-style-smoke.mjs`：Me/Cozymate 回归通过。
- 浏览器检查没有页面运行错误；测试使用独立浏览器及 4181 mock 服务，禁止外部或 API 请求。实际 4173 本地 Demo 也已打开并确认加载新样式。

详细结果见 [verification.json](images/verification.json)。
