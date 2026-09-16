# 补图判定：已按有限清单闭环

当前全部具名缺口及版本核对已完成，最终结果见 [交付验收](AUDIT.md)。下文保留判定过程，不重新开启历史待办。

# 本轮补图判定与复用清单

本表只细化原固定队列 G11，不新增测试矩阵。检查范围为独立页面清单、已索引截图及元数据、现有金图和相邻 UI 改版交付。完整任务仍未验收；“无整页缺图”和“全部状态完成”分开记录。

## 原 3 个缺图：现已补齐

以下 3 个状态已按原计划补齐，见 [截图、真实入口和后续结果](CONFIGURED-SUBMISSION-CURRENT.md)。两个定向场景严格通过；每态仅一张 390×844 完整图。下表保留补图前的判定依据，不能继续把它们作为待补项。

| 页面 | 实际触发与可见差异 | 查到的现有证据 | 最小补图范围 |
| --- | --- | --- | --- |
| 邀请登录 | 输入有效邀请码 → 提交未返回；输入禁用、按钮显示进度 | [本页](pages/invite.md)仅收录输入和本地校验；[提交实现](../../../lib/features/auth/presentation/invite_auth_page.dart)存在 `_submitting` 状态 | 提交中 1 态，不枚举设备、错误码和请求时序 |
| 数字形象创建 | Upload a photo → 选择照片 → 上传／发起生成尚未返回；按钮忙碌且其它操作禁用 | [创建页](pages/avatar-create.md)有默认、选图错误、已进入生成等图，上传中未收录 | 上传中 1 态，不把上传与生成请求各复制一张相同忙碌图 |
| 数字形象创建 | 照片上传并接受生成 → “Your digital companion is being created” 对话框；可等待或进入 App | [实现](../../../lib/features/onboarding/presentation/onboarding_page.dart)的 `_showGenerationHandoff`，已索引元数据未发现该标题；[生成等待图](../01-auth/onboarding-reading-generation-wait/default.png)是另一界面 | 对话框 1 态；等待／进入 App 的目标图复用，仅补操作对应关系 |

## 有证据，直接复用

| 对象 | 结论与证据 | 本轮动作 |
| --- | --- | --- |
| 数字形象激活完成 | [完整图](../01-auth/onboarding-reading-activation/default.png)显示完成标记、标题与返回说明；[原上下文](../01-auth/onboarding-reading-activation/README.md)保留 | 已实际查看，无需新增完成页截图；返回链继续引用既有路由测试，不能以组件截图代替路由证明 |
| 登录密码 Tooltip 长图 | [完整图](../01-auth/auth-journey-password-tooltip/default.png)为 393×897，顶部至隐私条款完整；Hide password 仅出现一次，位置正确；元数据滚动范围 0–53 | 旧采集器候选已排除拼接缺陷，无需重拍；该结论不扩展为整个登录页所有版本有效 |
| 数字形象错误／确认 | [照片错误](../01-auth/onboarding-photo-error/default.png)、[确认中](../01-auth/onboarding-avatar-short-confirm-busy/default.png)、[确认失败](../01-auth/onboarding-avatar-short-confirm-error/default.png)、[默认确认](../01-auth/onboarding-default-confirm/default.png)均已有 | 按宿主和真实触发引用，不扩展尺寸组合 |
| 共享系统窗口 | [15 张原生证据](NATIVE-WINDOWS-CATALOG.md) | 相同系统窗口跨入口共享截图，保留各入口链；不新增平台矩阵 |

## 原待核对项的收口结果

| 对象 | 具体未决问题 | 收口边界 |
| --- | --- | --- |
| 邀请提交失败及本机登录保存失败 | **已核对**：两种可见提示不同，补齐两张代表图 | [当前错误反馈](CONFIGURED-ERRORS-CURRENT.md)，实际重试后进入 More |
| 数字形象上传失败／默认激活失败 | **已核对**：相同服务端提示下，两条实际链严格匹配一张完整图 | [共享错误图与恢复结果](CONFIGURED-ERRORS-CURRENT.md)，不扩展错误码 |
| Agent 当前改版 | **已核对具名差异**：Markdown 差异仅为头像解码；补等待后原金图通过 | [当前复用说明](AGENT-CURRENT-REUSE.md)，行动／表单引用已有当前交付 |
| Agent 表单 | **当前交付已归属**：6 个源码／测试指纹匹配，沿用 72 张验证图 | [复用说明](AGENT-CURRENT-REUSE.md)；不单凭组件交付宣布全盘完成 |
| 页面／状态／浮层／操作链最终对应 | 34 个定义与 35 类浮层已列明，部分状态尚未逐项对应；类型观察候选为 0 不等于缺图 | 只整理既有证据。新增采集项必须写出实际控件、可见差异、已查证据与最小截图范围，不以“继续核对”扩展组合 |

## 执行与结束条件

- 保留原始 Page × State × Interaction 要求、长图要求和正常入口条件；工作台单列。
- 同页完整图像素相同则共享代表图，多入口仍保留原 README 的前驱与后续链；不同文案、选中态、布局不能机械折叠。
- 整理后仅为上述 3 个具名缺口新增两项定向操作场景及三张基线，最终严格采集通过；未修改产品代码或扩大测试矩阵。
- 本轮整理交付完成；全量 UI 盘点仍待上述缺口及对应关系闭环，不能使用测试数量或页面数量计算完成率。
