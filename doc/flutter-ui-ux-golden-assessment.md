# Flutter UI/UX Golden 标准评估

> 状态：评估稿 v0.1  
> 评估日期：2026-07-03  
> 工作分支：`feat/test2`  
> 基线标准：`doc/legacy-web-ui-ux-golden-standard.md`  
> 范围：评估当前 Flutter App 是否满足旧 Web UI/UX Golden 标准的页面结构、视觉层级、关键交互和测试准入。  

---

## 1. 总体结论

当前 Flutter 版本相对已采用的旧 Web UI/UX Golden 标准，结论为：

```text
有条件通过当前阶段 UI/UX 评估。
可以作为继续推进 Flutter 替代 Web 的当前 UI 基线。
但还不能宣布已经完成像素级、全状态、全设备的最终视觉验收。
```

本次评估未发现阻断继续推进的 P0 UI/UX 问题。当前源码内已覆盖主要页面、主导航结构、专注流程隐藏底栏、核心文案、主色调、卡片材质和大部分关键交互。

仍然需要补齐的主要差距集中在：

- 旧 Web / Flutter 对照评审：旧 Web 390x844 reference screenshot 已固化，但还缺逐页 side-by-side 评审记录。
- 深状态 golden：主要页面已补 360x800、390x844、430x932，但很多交互状态仍只有 widget 测试，没有 golden 图。
- 真机视觉/安全区/系统栏验证：本评估不包含 Android 真机、异形屏、系统字体缩放和导航手势验证。

因此当前建议是：Flutter UI/UX 可以继续作为迁移主线推进，但进入最终替代旧 Web 前，需要完成第 8 节列出的补充验收项。

---

## 2. 评估依据

### 2.1 Source of Truth

本评估采用以下文档为 UI/UX 判断标准：

```text
doc/legacy-web-ui-ux-golden-standard.md
```

该标准明确：旧 Web 不是视觉灵感，而是替换前的产品基线。Flutter 默认不得重设计旧 Web 的信息架构、页面层级、关键控件、文案和主要视觉比例。

### 2.2 Flutter 当前证据

当前 Flutter golden 覆盖：

```text
flutter_app/test/goldens/agent_hub/rich_state_mobile.png
flutter_app/test/goldens/agent_hub/narrow_360x800/rich_state_mobile.png
flutter_app/test/goldens/agent_hub/large_430x932/rich_state_mobile.png
flutter_app/test/goldens/feature_pages/agent_hub_mobile.png
flutter_app/test/goldens/feature_pages/narrow_360x800/*.png
flutter_app/test/goldens/feature_pages/large_430x932/*.png
flutter_app/test/goldens/feature_pages/calibration_page_mobile.png
flutter_app/test/goldens/feature_pages/community_page_mobile.png
flutter_app/test/goldens/feature_pages/device_manage_page_mobile.png
flutter_app/test/goldens/feature_pages/device_page_mobile.png
flutter_app/test/goldens/feature_pages/device_user_page_mobile.png
flutter_app/test/goldens/feature_pages/hospital_bag_page_mobile.png
flutter_app/test/goldens/feature_pages/ibclc_page_mobile.png
flutter_app/test/goldens/feature_pages/media_viewer_page_mobile.png
flutter_app/test/goldens/feature_pages/not_found_page_mobile.png
flutter_app/test/goldens/feature_pages/pump_page_mobile.png
flutter_app/test/goldens/feature_pages/records_page_mobile.png
flutter_app/test/goldens/feature_pages/schedule_page_mobile.png
flutter_app/test/goldens/feature_pages/status_page_mobile.png
flutter_app/test/goldens/feature_pages/w1_page_mobile.png
```

当前 Flutter 主页面 golden 总数为 48：

- 15 个 feature 页面 x 3 个移动视口。
- 1 个 Agent Hub rich state x 3 个移动视口。

当前 Flutter 自动化验证结果：

| 命令 | 结果 |
|---|---|
| `flutter analyze` | 通过，No issues found |
| `flutter test` | 通过，293 个测试全部通过 |

测试覆盖范围包含：

- 路由壳与底部导航。
- 全部非 Agent 页面渲染。
- compact mobile 页面 golden。
- Agent Hub rich state golden。
- Agent SSE/WebSocket transport-agnostic 流处理。
- BLE protocol fixture。
- Storage migration。
- Route intent。
- Device permission / connected / denied 状态。
- Pump session 状态机。
- Records、Schedule、Status、IBCLC、Hospital Bag 等核心交互。

---

## 3. 评估口径

本次评估将结论分为四档：

| 状态 | 含义 |
|---|---|
| 通过 | 当前 Flutter 实现已满足旧 Web 黄金标准的主路径要求，并有测试或 golden 支撑。 |
| 有条件通过 | 主路径已满足，但仍缺少部分状态 golden、自动截图对照或真机验证。 |
| 未通过 | 当前 Flutter 与旧 Web 标准存在明显结构、视觉、文案或关键交互差异。 |
| 需产品决策 | Flutter 与旧 Web 存在实现差异，但可能是合理移动原生调整，需要产品确认。 |

注意：本次评估不是像素级截图 diff。当前已有旧 Web 390x844 Playwright reference screenshot，但还没有把旧 Web reference 与 Flutter golden 做自动像素 diff；判断依据仍然是旧 Web 源码、黄金标准文档、旧 Web reference、Flutter 源码、Flutter golden 和测试结果。

---

## 4. 全局标准评估

| 标准项 | 结论 | 说明 |
|---|---|---|
| 信息架构 | 通过 | Flutter 已保留宝宝和我、计划、智能体、社区、设备五个底部主入口，以及 Pump、Calibration、Media、IBCLC 等专注流程。 |
| 底部导航 | 通过 | 五个 tab 均可见，中心智能体头像按钮保留旧版凸起结构，专注流程隐藏底栏。 |
| 画布与安全区 | 有条件通过 | 360x800、390x844、430x932 主页面 golden 下没有发现首屏主路径裁切；仍需真机验证状态栏、手势导航和不同系统字体缩放。 |
| 主题色与材质 | 通过 | 当前 Flutter 已采用 rose/cocoa 调性、柔和卡片、primary active、muted foreground 等旧版视觉语言。 |
| 字体与文案 | 有条件通过 | 主要页面文案接近旧 Web；仍需产品或设计对每个业务文案做最终逐项确认。 |
| 页面滚动结构 | 通过 | Tab 页面采用主滚动区域；专注流程独立全屏；没有再出现右侧半张主卡片误露的问题。 |
| 旧版可见控件保留 | 有条件通过 | 主路径控件已保留；部分深状态还缺 golden 图来锁定。 |
| 不裁切、不隐藏、不露半张卡 | 有条件通过 | 360x800 窄屏 golden 暴露并修复了校准宽卡裁切；剩余静态扫描命中均有解释，仍需深状态 golden 和真机验证。 |
| 可测试性 | 通过 | 当前 Flutter 自动化测试通过，且页面/golden/协议/状态机测试已建立。 |
| 多视口视觉验收 | 有条件通过 | 主页面和 Agent rich state 已覆盖 360x800、390x844、430x932；深状态 golden 仍需补齐。 |

---

## 5. 静态扫描结果

为排查“用户看到不完整界面、隐藏旧控件、横向溢出”等风险，本次扫描了 Flutter 页面源码中的可疑模式：

```text
Opacity(opacity: 0)
SizedBox.shrink()
Visibility
Offstage
Transform.translate
scrollDirection: Axis.horizontal
OverflowBox
clipBehavior: Clip.none
```

剩余命中解释如下：

| 位置 | 结论 | 说明 |
|---|---|---|
| `flutter_app/lib/app/momcozy_app.dart` bottom nav | 可接受 | `Clip.none` 和 `Transform.translate` 用于旧 Web 中心智能体按钮的凸起效果。 |
| `momcozy_feature_pages.dart` status cards | 可接受但建议后续清理 | `Opacity(opacity: 0)` 用于测试/辅助文本，不是用户可见控件。后续可改为更明确的 semantics/test hook。 |
| `momcozy_feature_pages.dart` calibration | 已修正 | 360px 窄屏 golden 发现旧宽卡裁切风险后，已改为“最多 396px 且不超过可用宽度”的响应式宽卡。 |
| `momcozy_feature_pages.dart` records chart | 可接受 | 有数据时 `SizedBox.shrink()` 只是 CustomPaint 图层里的空占位。 |
| `momcozy_feature_pages.dart` W1 / Media / NotFound | 可接受 | `Transform.translate` 用于旧版视觉垂直位置微调。 |

本轮没有发现未解释的横向滚动主布局、隐藏用户操作入口或明显裁切风险。

---

## 6. 页面级评估

### 6.1 Agent Hub `/`

结论：有条件通过。

已满足：

- 保留主 Agent 入口作为底部中心 tab。
- 已有普通 Agent 页面 golden 和 rich state golden。
- Agent 文本流已按 transport-agnostic 设计，可通过 SSE 或 WebSocket 归一到同一事件流。
- 工具进度、streaming、finished、cancel/error 状态已有自动化测试。

仍缺：

- 图片上传、语音输入、错误重试、空响应、长消息等状态的独立 golden。
- 旧 Web AG-UI rich component 与 Flutter rich card 的逐项视觉对照。

### 6.2 宝宝和我 `/status`

结论：有条件通过。

已满足：

- 妈妈/宝宝档案 tab 保留。
- 状态同步失败、下一步、孕期日记、今日待办等主结构保留。
- 状态页已有成功、空态、失败、长文本、成长记录等 widget 测试。

仍缺：

- 妊娠期/哺乳期切换的视觉 golden。
- 宝宝 tab、通知 badge 转移、成长趋势深状态 golden。
- 旧 Web 中隐式状态文案与 Flutter 文案逐条核对。

### 6.3 计划 `/schedule`

结论：有条件通过。

已满足：

- 日期切换、提醒上下文、任务列表、Agent 建议入口和 badge 结构保留。
- 添加、删除、本地任务、跨天倒计时、空态/失败态已有测试。

仍缺：

- 新增任务弹窗、提醒开关、跨天倒计时和失败态的 golden。
- 系统通知权限拒绝/重试的视觉状态 golden。

### 6.4 设备 `/device`

结论：有条件通过。

已满足：

- 页面标题、右上新增入口、W1 横幅、Air One 设备区域、左右设备卡片和连接按钮保留。
- 空结果、权限拒绝、永久拒绝、双设备、扫描和连接结果已有测试。
- 当前 compact golden 已覆盖主路径，不再出现右侧主卡片半露造成的明显残缺问题。

仍缺：

- 权限弹窗引导、已连接/断开/重连、扫描中、扫描超时的 golden。
- 真机 BLE 权限模型和系统弹窗验证。

### 6.5 设备管理 `/device/manage`

结论：通过。

已满足：

- 保留设备提醒/管理子页结构。
- 路由和页面 golden 已覆盖。
- reminder route 与 native intent 有测试覆盖。

仍缺：

- 后端加载中、同步失败、提醒开关批量变更的状态 golden。

### 6.6 用户参数 `/device/user`

结论：通过。

已满足：

- 保留用户参数配置页、输入项、选择项、底部保存动作。
- 页面 golden 已覆盖。

仍缺：

- 下拉选择展开、保存失败、校验错误的状态 golden。

### 6.7 W1 `/w1`

结论：通过。

已满足：

- 保留 W1 推广页的 hero、产品摘要、核心亮点、教程入口。
- 教程入口跳转 Media Viewer 的事件链已有测试。

仍缺：

- 实际营销资源图和文案仍需产品最终确认。

### 6.8 泵奶 `/pump`

结论：有条件通过。

已满足：

- 专注流程隐藏底栏。
- 保留左右侧数据、档位、阶段、开始/暂停/恢复/结束、校准入口等核心结构。
- 本地 session 状态、上传 workstate、重复结束保护、用户切换清理和上传失败状态已有测试。

仍缺：

- running、paused、finished、upload failed、foreground restore 等状态的 golden。
- 真泵、后台服务、通知恢复和只上传一次仍属于真机/集成验证范围。

### 6.9 舒适校准 `/calibration`

结论：有条件通过。

已满足：

- 专注流程隐藏底栏。
- 保留顶部进度、返回、步骤卡、左右设备状态、左右档位、保存进入泵奶、退出、恢复默认。
- 保存档位、无设备错误、右侧/双侧设备、未保存恢复已有测试。

仍缺：

- 中断恢复、保存失败、单侧设备等状态 golden。

### 6.10 记录 `/records`

结论：有条件通过。

已满足：

- 保留月切换、汇总卡、趋势、泵奶/喂养/成长记录、手动补录、单位切换。
- mL/oz、添加/编辑/删除、跨天记录、空态/失败态已有测试。

仍缺：

- 旧 Web 是否依赖 swipe reveal 行操作，需要产品确认。当前 Flutter 显式编辑/删除更移动原生，但不一定是旧版完全一致。
- edit/delete、mL/oz、失败态和空态的 golden。

### 6.11 Media Viewer `/media-viewer`

结论：有条件通过。

已满足：

- 专注流程隐藏底栏。
- 缺少资源参数、query 资源解析、返回上一页已有测试。
- 主 chrome 和 missing resource golden 已覆盖。

仍缺：

- PDF/image/video 实际渲染状态 golden。
- 加载失败、长标题、外部资源权限失败状态 golden。

### 6.12 IBCLC `/ibclc-chat.html`

结论：有条件通过。

已满足：

- 专注咨询流程隐藏底栏。
- 保留连接顾问、排队/失败降级、vendor handoff、返回状态页等核心链路。
- client event、sync failed、本地队列、vendor handoff 已有测试。

仍缺：

- 聊天 ready、消息发送中、结束咨询、vendor 返回后的 golden。
- 真实第三方咨询入口仍需集成验证。

### 6.13 Hospital Bag `/hospital-bag-cart`

结论：有条件通过。

已满足：

- 保留待产包购物车分组、数量、删除、恢复默认和同步失败链路。
- cart sync、删除、恢复默认、失败态已有测试。
- 页面 golden 已覆盖主路径。

仍缺：

- 删除确认、空购物车、恢复默认、同步失败的 golden。

### 6.14 Community `/community`

结论：通过。

已满足：

- 当前旧版社区是建设中/空态属性，Flutter 已保留中心空态。
- 页面 golden 已覆盖。

### 6.15 Not Found `*`

结论：通过。

已满足：

- 保留 recoverable not found 路由。
- 页面 golden 和路由测试已覆盖。

---

## 7. 当前通过清单

当前 Flutter 已经满足以下迁移前 UI/UX 条件：

- 主页面均有 Flutter 实现，不再是空壳。
- 所有主 tab 可见，不存在底栏少 tab 的当前代码问题。
- 主 tab 页面不会再出现右侧半张卡片作为默认可见布局。
- Pump、Calibration、Media Viewer、IBCLC 等专注流程会隐藏底栏。
- 当前 360x800、390x844、430x932 mobile golden 覆盖所有主页面。
- `flutter analyze` 通过。
- `flutter test` 通过，293 个测试全部通过。
- Agent 文本流已按 transport-agnostic 架构设计，不把 UI 绑定到单一 WebSocket 实现。

---

## 8. 进入最终 UI 验收前必须补齐

### P1 必补

1. 完成旧 Web reference 与 Flutter golden 的逐页 side-by-side 评审记录。

2. 增加深状态 golden：
   - Agent：streaming、error retry、image upload、long message。
   - Status：妈妈/宝宝切换、失败态、成长记录、孕期日记入口。
   - Schedule：新增弹窗、提醒关闭、跨天倒计时、空态/失败态。
   - Device：权限拒绝、永久拒绝、扫描中、扫描空结果、左右已连接。
   - Pump：running、paused、finished、upload failed、restore prompt。
   - Calibration：单侧设备、双侧设备、保存失败、恢复中断。
   - Records：mL/oz、编辑、删除、空态、失败态。
   - Media：PDF、image、video、加载失败。
   - IBCLC：排队、会话中、结束、vendor 返回。
   - Hospital Bag：删除后、空购物车、同步失败、恢复默认。

3. 建立视觉 diff 评审门槛：
   - Flutter golden 变化必须说明对应旧 Web 标准条目。
   - 若 Flutter 与旧 Web 不一致，必须标记为产品决策或 bug。
   - 禁止以“原生重构”为理由默认改变页面信息架构。

### P2 建议补

1. 用 semantics/test hook 替换不可见文本测试辅助。
2. 明确 Records 行操作是否继续沿用旧 Web swipe reveal，还是接受 Flutter 显式操作按钮。
3. 持续观察 Calibration 响应式宽卡在真实 Android 设备上的安全区表现。
4. 明确 debug / demo 用户入口是否允许在非内部环境出现。
5. 增加系统字体缩放 1.15x / 1.3x 的视觉 smoke。

---

## 9. 风险判断

当前没有发现需要立刻回滚或阻断迁移的 UI/UX 风险。

主要风险不是“Flutter 当前页面完全不对”，而是“验收基线还不够自动化”。旧 Web reference 和 Flutter 多视口 golden 已经补齐主路径，但如果不补 side-by-side 评审记录和 deep-state golden，后续继续改页面时仍可能出现视觉漂移，且很难判断某个差异是合理原生化还是无意回归。

---

## 10. 建议下一步

建议按以下顺序继续推进：

1. 按第 8 节补深状态 golden。
2. 对第 8 节 P2 的产品决策项做确认。
3. 在所有非真机 UI golden 通过后，再进入 Android emulator smoke 和真机设备验证。

本次评估给出的迁移准入结论是：

```text
Flutter UI/UX 当前可继续推进。
不建议在补齐 reference screenshot 对照评审、深状态 golden 和真机验证前宣布最终 UI 完全验收。
```
