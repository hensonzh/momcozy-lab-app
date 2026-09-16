# 妈妈模块控件覆盖清单（持续审计）

收口说明：本文保留历史逐控件记录。旧末列中的额外请求时序、错误码、尺寸和字段组合不自动进入当前补图队列；当前按 [页面与操作链对应](PAGE-INTERACTION-MAP.md)、[浮层对应](OVERLAY-EVIDENCE-MAP.md) 与 [具名缺口判定](CAPTURE-DECISIONS.md) 核对。确有可见差异且未找到证据的条目仍须明确记录，不能一概当作已完成。

此清单按生产控件和实际点击证据核对。截图存在不等于入口已遍历，测试组件直接挂载不升级为正常路径证据。尚未逐项证明的条目保持待补。

| 页面 / 控件 | 当前实际路径证据 | 剩余范围 |
| --- | --- | --- |
| 首页 AI、泌乳、今日状态、专家总入口与已购计划 | [Mom 路由链](MOM-JOURNEYS.md)、[服务流程](SERVICE-JOURNEYS.md) | 条件与所有数据组合仍按有意义状态审计 |
| 休息 7 组 / 32 个选项 | [逐项选择](MOM-REST-CONTROLS.md)；393/1x 全选项，320/2x 每组末项与提交链 | 时长清空已有证据；[其余五组清空、恢复与保存重开](MOM-REST-CLEAR-CONTROLS.md) 已补齐 |
| 休息影响原因多选 | 6 项逐个选中再逐个取消、全空与重新选择已验 | 无需枚举没有产品意义的全部组合 |
| 休息补充展开 / 折叠 / 保存 / 重开 | 选填→已填写、关闭保存提示、首页刷新和持久值回显已验 | 跨日等通用分支另由现有流程覆盖 |
| 身体电量 3 项、不适部位 6 项 | [逐控件运行](MOM-BODY-CONTROLS.md)，全部选择、逐个取消、关联清空与恢复已验 | 小屏每组末项及完整保存链；非所有组合穷举 |
| 不适程度 / 影响 / 相对昨天趋势 | [各 3 项逐点、清空、恢复和保存](MOM-BODY-CONTROLS.md) | 已覆盖现有选项，跨日等共享条件继续审计 |
| 排尿 / 排便 | [各 3 项选择、清空及重开回显](MOM-BODY-CONTROLS.md) | 已填写时标题仍为“可选”的实际表现已记录 |
| 身体备注 | [输入、清空、再填、保存和回显](MOM-BODY-CONTROLS.md) | [1999/2000/2001 字、内部滚动首尾和保存重开](MOM-NOTE-BOUNDARIES.md) 已验；原生键盘仍待核验 |
| 心情 5 项与首页 3 个快捷入口 | [所有选项、快捷预填、放弃、清空恢复与保存回显](MOM-MOOD-CONTROLS.md) | 已验 393/1x 全选项，320/2x 末项及完整链 |
| 压力 8 项 / 排他选项 | [普通→排他→普通、逐项全清与恢复](MOM-MOOD-CONTROLS.md) | 不穷举无产品意义的多选组合 |
| 心情影响 / 支持 | [各 3 项点击、清空恢复、保存重开](MOM-MOOD-CONTROLS.md) | 清空最后已存字段会触发空提交校验，原记录保留，非删除 |
| 记录页 Tab / 关闭 / 提交 | [空提交](../03-mom/mom-journey-diary-empty-validation/README.md)、[错误重试](../03-mom/mom-journey-diary-save-error/README.md)、[冲突](../03-mom/mom-journey-diary-conflict/README.md) | 对照当前 Controller 条件继续核对，不将共享流程当作每字段全部覆盖 |
| 泌乳新增 / 编辑 / 删除 / 撤销 | [已有泌乳流程](MOM-JOURNEYS.md) | [左右侧、方式互切、四种感受逐项取消、备注清空、有效时间确认、保存重开](MOM-MILK-CONTROLS.md) 已补齐 |
| 泌乳校验与其它返回方式 | 上述报告与已有错误场景 | [备注长度边界已验](MOM-NOTE-BOUNDARIES.md)；[数值与未来时间校验、上午下午、返回记录及 Flutter 平台返回已验](MOM-MILK-VALIDATION.md)；[表盘点选、时分切换、午夜/正午与水平滚动已验](MOM-MILK-DIAL.md)；原生输入与设备返回仍需核对 |

正式源文件：`lib/modules/mom/presentation/diary_fields.dart`、`diary_labels.dart`、`mother_diary_editor.dart`、`lactation_panel.dart`。本清单没有将工作台、未注册动作评估或设计稿未实现页面列为用户 App 可达路径。
