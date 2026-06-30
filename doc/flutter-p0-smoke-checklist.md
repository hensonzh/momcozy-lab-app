# Flutter P0 真机与真泵 Smoke Checklist

> 状态：Phase 0 可执行清单。  
> 目的：Flutter shell 和核心 native PoC 出来后，用同一张表验证 Android 版本差异、BLE、Pump session、Agent stream 和数据上传。  
> 结论规则：P0 任一阻断项失败，不能替换现有 Capacitor App。

---

## 1. 执行信息

| Field | Value |
|---|---|
| Build |  |
| Commit / branch |  |
| Tester |  |
| Date |  |
| Backend env |  |
| Pump firmware |  |
| Notes |  |

---

## 2. 设备矩阵

至少覆盖：

```text
[ ] Android 11 或以下权限模型
[ ] Android 12 BLE runtime permission 模型
[ ] Android 13+ notification runtime permission 模型
[ ] 一台低端或内存紧张设备
[ ] 一台厂商深度定制系统设备
[ ] 左侧真泵
[ ] 右侧真泵
[ ] 双侧真泵
```

---

## 3. P0 Smoke 表

| ID | 场景 | 步骤 | 预期结果 | Result | Notes |
|---|---|---|---|---|---|
| BOOT-01 | 安装启动 | 安装 debug/release build，冷启动。 | App 不崩溃，进入 Agent Hub 或安全默认页。 |  |  |
| BOOT-02 | 热启动 | Home 后重新打开。 | 当前 tab、必要 session id 和 pending intent 状态正确。 |  |  |
| BOOT-03 | 杀进程恢复 | 杀进程后从 launcher 打开。 | 不信任 stale BLE connected flag，不重复消费旧 intent。 |  |  |
| AUTH-01 | demo user 初始化 | 使用 demo user 进入主流程。 | user scope storage、API query 和日志脱敏正常。 |  |  |
| PERM-01 | BLE 首次允许 | 进入 Device，授予 BLE 权限。 | 可扫描设备，不展示错误态。 |  |  |
| PERM-02 | BLE 拒绝 | 拒绝 BLE 权限后重试。 | 展示可恢复提示，可打开系统设置。 |  |  |
| PERM-03 | 通知权限 | Android 13+ 首次请求通知权限。 | 前台服务和普通提醒有明确降级。 |  |  |
| PERM-04 | 麦克风权限 | Agent 语音输入请求权限。 | 允许后可录音，拒绝后不崩溃。 |  |  |
| PERM-05 | Overlay 权限 | 如果保留悬浮窗，打开授权页并返回。 | 授权状态刷新，未授权时降级到通知。 |  |  |
| BLE-01 | 扫描 | Device 页扫描。 | 能发现目标泵，空结果有可读提示。 |  |  |
| BLE-02 | 左设备连接 | 连接左泵。 | L side connected，R side 不被污染。 |  |  |
| BLE-03 | 右设备连接 | 连接右泵。 | R side connected，L side 不被污染。 |  |  |
| BLE-04 | 重连 | 断开再连接。 | notify 重新订阅，pending request 清理。 |  |  |
| BLE-05 | E1 状态解析 | 连接后查询设备状态。 | mode、gear、scene、workState、battery、calibration 正确映射。 |  |  |
| CAL-01 | 无校准进入 Pump | 清空校准后进入 Pump。 | 提示先校准或走安全默认，不使用非法 legacy 值。 |  |  |
| CAL-02 | 双侧校准 | 完成 L/R 校准并保存。 | storage migration schema 可读，Pump 初始档位正确。 |  |  |
| PUMP-01 | 启动 Pump | 双侧连接后启动。 | 两侧按预期启动，UI、native service、通知同步。 |  |  |
| PUMP-02 | 暂停/恢复 | 暂停后恢复。 | workState、duration、UI button 文案正确。 |  |  |
| PUMP-03 | 调档/模式 | 调整左右档位、模式、自动/手动。 | 左右互不串扰，B1/native side command 成功。 |  |  |
| PUMP-04 | 后台运行 | Pump 运行中按 Home，等待 5 分钟。 | 前台服务继续，通知可见，计时不丢。 |  |  |
| PUMP-05 | 锁屏恢复 | 锁屏 2 分钟后解锁。 | Pump session 状态恢复，BLE 不误判。 |  |  |
| PUMP-06 | 通知点击恢复 | 点击 Pump foreground notification。 | 回到 Pump route，pending intent 只消费一次。 |  |  |
| PUMP-07 | 悬浮窗 | 如果保留 overlay，后台显示/关闭悬浮窗。 | 状态与主 App 同步，未授权时不崩溃。 |  |  |
| PUMP-08 | 结束 Pump | 点击结束。 | BF/FE 流程按设计执行，session 进入 completed。 |  |  |
| UPLOAD-01 | summary 上传 | Pump 结束后上传 summary。 | `event_id` 幂等，成功只上传一次。 |  |  |
| UPLOAD-02 | milk record 上传 | Pump 结束后上传 milk record。 | 奶量与 UI snapshot 一致，只上传一次。 |  |  |
| UPLOAD-03 | Agent context 上传 | Pump 结束后推送 Agent context。 | conversation/thread id 正确，失败可重试或登记。 |  |  |
| AGENT-01 | 文本 Agent | Agent Hub 发送文本。 | 首帧及时，TEXT delta 流式展示，RUN_FINISHED 结束。 |  |  |
| AGENT-02 | 工具流 | 触发工具调用。 | tool start/args/end/result 合并为同一 work item。 |  |  |
| AGENT-03 | Artifact | 触发 card/form artifact。 | artifact 独立渲染，不从文本猜 schema。 |  |  |
| AGENT-04 | 取消 | 流式输出中取消。 | transport 关闭，调用 cancel，输入恢复。 |  |  |
| AGENT-05 | 断线 | 中途断网或关闭后端。 | 展示可重试错误，partial content 保留。 |  |  |
| VOICE-01 | 语音输入 | 麦克风输入并转写。 | STT 有结果或可恢复错误。 |  |  |
| VOICE-02 | 自动播放 | Agent 文本流触发 TTS。 | 可播放、可打断，不覆盖通知语音状态。 |  |  |
| ROUTE-01 | 计划提醒跳转 | 触发 schedule reminder notification。 | 跳转到 Schedule，并只消费一次。 |  |  |
| ROUTE-02 | milk analysis 跳转 | 触发 milk analysis notification。 | 跳转到目标 route / artifact anchor。 |  |  |
| DATA-01 | Records 查询 | 打开 Records。 | 列表/图表可展示，mL/oz 不错位。 |  |  |
| DATA-02 | Schedule 查询 | 打开 Schedule 并切换日期。 | 任务、提醒状态、badge 正确。 |  |  |
| DATA-03 | Status 查询 | 打开 Status。 | 妈妈/宝宝 tab 和 care stage 正确。 |  |  |
| STORAGE-01 | legacy storage dry-run | 带旧 localStorage/sessionStorage 启动。 | 迁移幂等，非法值 fallback，多用户隔离。 |  |  |
| LOGOUT-01 | 切换用户 | 切换或登出 demo user。 | BLE 断开或隔离，chat/calibration/device/storage 不串用户。 |  |  |

---

## 4. 通过标准

```text
[ ] 所有 BOOT / AUTH / PERM / BLE / CAL P0 项通过
[ ] Pump 启动、暂停、恢复、结束、后台、通知恢复通过
[ ] summary、milk record、Agent context 均只上传一次
[ ] Agent text stream、tool stream、artifact、取消、断线通过
[ ] Storage migration dry-run 通过
[ ] 无 P0 crash
[ ] 无真实用户数据或 token 出现在日志、截图、fixtures 中
```

---

## 5. 失败登记模板

```text
ID:
Device:
Android version:
Build:
Steps:
Expected:
Actual:
Logs / screenshots:
Severity: P0 / P1 / P2
Owner:
Decision: fix before migration / accept as baseline / drop feature
```
