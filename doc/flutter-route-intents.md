# Flutter 路由与通知 Intent 矩阵

> 状态：Phase 0 inventory + fixtures 版  
> 目标：把当前 BrowserRouter、通知跳转、AG-UI side effects、pending storage 和 native bridge 事件整理成 Flutter route intents。

---

## 1. 当前路由表

| Route | Current page | Flutter route intent | Bottom nav | Migration |
|---|---|---|---|---|
| `/` | `AgentHub` | `AgentHubIntent` | show | P0 |
| `/calibration` | `ComfortCalibration` | `CalibrationIntent` | hide | P0 |
| `/pump` | `PumpSession` | `PumpSessionIntent` | hide | P0 |
| `/records` | `Records` | `RecordsIntent` | show | P1 |
| `/schedule` | `Schedule` | `ScheduleIntent` | show | P1 |
| `/status` | `Status` | `StatusIntent` | show | P1 |
| `/community` | `Community` | `CommunityIntent` | show | TBD |
| `/device` | `DeviceManagement` | `DeviceIntent` | show | P0 |
| `/device/manage` | `DeviceManageActions` | `DeviceManageIntent` | show | P1 |
| `/device/user` | `UserParameterConfig` | `DebugUserIntent` | show/dev-only | TBD |
| `/w1` | `W1Promo` | `PromoIntent` | show | TBD |
| `/hospital-bag-cart` | `HospitalBagCart` | `HospitalBagCartIntent` | show | TBD |
| `/ibclc-chat.html` | `IbclcChat` | `IbclcIntent` | route-specific | TBD |
| `/media-viewer` | `MediaViewer` | `MediaViewerIntent` | hide | P1 |
| `*` | `NotFound` | `NotFoundIntent` | show | P2 |

---

## 2. App-level listeners

| Current sync | Source | Current behavior | Flutter target |
|---|---|---|---|
| `PumpNotificationNavigateSync` | `src/App.tsx`; `src/lib/pumpSessionNotification.ts` | 消费 native pending path / notifyJson，然后 `navigate(path)`。 | `RouteIntentQueue.consumePumpNotificationIntent()` |
| `PumpOverlayRouteSync` | `src/App.tsx`; `src/lib/pumpSessionOverlay.ts` | 路由变化通知 overlay，避免 overlay 与当前页面冲突。 | `PumpOverlayRouteObserver` |
| `DeviceReminderWebSocketSync` | `src/App.tsx`; `src/lib/deviceReminderWebSocket.ts` | App 启动后启动 device reminder WebSocket。 | native notification/realtime coordinator |
| `AgentNotificationVoiceSync` | `src/App.tsx` | 接收 notification chat message 并播报语音。 | `AgentNotificationVoiceCoordinator` |
| `BackgroundNotifyOnboardingGate` | `src/components/system/BackgroundNotifyOnboardingGate.tsx` | 首次提示后台通知相关能力。 | Flutter onboarding gate + permission state |

---

## 3. Native notification intents

| Event/source | Current payload | Current destination | Flutter intent | Notes |
|---|---|---|---|---|
| Pump foreground notification tap | pending path from native bridge | `/pump` or `/` | `OpenPumpSession` / `OpenAgentHub` | 需要只消费一次。 |
| Pump auto-end notification | `autoEndTeardown` + path | `/` | `OpenAgentHubAndRunPumpTeardown` | 需要确保 summary/milk record/Agent context 只上传一次。 |
| Daily summary | `notifyJson.event = "summary"` | `/` + Agent message | `OpenAgentHubWithNotificationMessage` | 需要 personalize text。 |
| Mom/baby summary | `notifyJson.event = "mom_baby"` | `/` + Agent message | `OpenAgentHubWithAnalysisCard` | 带 analysis card/context。 |
| Milk analysis | `notifyJson.event = "milk_analysis"` | `/` + Agent message + follow-up | `OpenAgentHubWithMilkAnalysis` | 需要 context event 和 follow-up queue。 |
| Growth update | `notifyJson.event = "grown"` | `/status` highlight | `OpenStatusGrowthHighlight` | 当前通过 sessionStorage pending highlight。 |
| Health issue | `notifyJson.event = "health_issue"` | `/` + Agent notification | `OpenAgentHubWithHealthIssue` | 高敏感文案必须脱敏。 |
| Schedule reminder | native service path | `/schedule?mmcNotify=1` | `OpenScheduleReminder` | URL query 已转为 typed intent。 |

---

## 4. AG-UI / artifact side effects

| Source | Current mechanism | Flutter intent |
|---|---|---|
| Agent button/card route | `parseSwitchRouteFromValue`; `navigate(route)` | `AgentArtifactRouteIntent` |
| Calibration card | Agent Hub button to `/calibration` | `OpenCalibrationFromAgent` |
| Media link | `openMediaViewer()` with route state | `OpenMediaViewer(media)` |
| Plan feedback | `planNotificationFromAgUiData()` + localStorage pending | `ShowPlanBadge` / `OpenSchedule` |
| Birth journey plan | `markBirthJourneyPlanGeneratedNotification()` | `ShowStatusBirthJourneyBadge` |
| Pregnancy diary | `markPregnancyDiaryChangedNotification()` | `ShowStatusPregnancyDiaryBadge` |
| Milk analysis reminder follow-up | `mmc_milk_analysis_reminder_followup_pending` | `EnqueueAgentFollowup` |

---

## 5. Feature-to-feature navigation

| From | Trigger | Current route | Flutter intent |
|---|---|---|---|
| Agent Hub | Start pump gate lacks calibration | `/calibration` | `OpenCalibrationRequired` |
| Agent Hub | Start pump gate lacks device | `/device` | `OpenDeviceRequired` |
| Device panel | Start pump requires calibration | `/calibration` | `OpenCalibrationRequired` |
| Device panel | Start pump ok | `/pump` | `OpenPumpSession` |
| Pump session | missing connected device | `/device` | `OpenDeviceRequired` |
| Pump session | calibration route | `/pump?from=calibration&autoStarted=1` | `OpenPumpSession(autoStartedFromCalibration: true)` |
| Records | status shortcut | `/status` | `OpenStatus` |
| Schedule | ask Agent to adjust schedule | `/` with `agentPrefill` state | `OpenAgentHubWithPrefill` |
| IBCLC | return after consult | `return_to` + viewport storage | `ReturnFromIbclc` |

---

## 6. Route intent design requirements

```text
[x] Route intents are typed objects, not raw strings, beyond deep-link boundary
[x] Notification intents are queued and consumed once
[x] Intent queue is user-scoped when payload contains user data
[x] Native notification payload is sanitized before entering Agent message timeline
[x] Media viewer receives typed media descriptor, not only raw URL
[x] `/pump?from=calibration&autoStarted=1` becomes typed flags
[x] `/schedule?mmcNotify=1` becomes typed notification source
[x] IBCLC return viewport is optional and best-effort
[x] Unknown route falls back to Agent Hub or NotFound without crash
```

## 7. Phase 0 fixtures

已创建可执行 route intent fixtures：

```text
test/fixtures/route_intents/
  native_notification_analysis_intents.json
  pump_notification_and_overlay_intents.json
  plan_and_diary_pending_intents.json
  agent_artifact_and_feature_navigation_intents.json
  media_viewer_and_ibclc_return_intents.json
  malformed_and_unknown_route_fallbacks.json
```

这些 fixtures 覆盖：

- native notification `notifyJson` 到 AgentHub / Status / Schedule 的 typed intent。
- pump foreground notification、auto-end teardown 和 overlay route observer。
- plan、pregnancy diary 的 pending storage 到 badge/navigation intent。
- AG-UI artifact、feature-to-feature navigation、query/state/custom event 的 typed 化。
- media viewer 和 IBCLC return viewport。
- malformed payload、unsafe route 和 unknown route fallback。

当前进展：Flutter `go_router` 核心 route shell 已接入，覆盖当前路由表的主路径、底部导航、专注流程隐藏底栏和 NotFound fallback，并已接入 `RouteIntentPlatform` 消费 native pending route 与 active route event。`test/app/momcozy_route_shell_contract_test.dart` 已读取 route intent fixtures，断言非 NotFound 目标路径均已注册到 route map。`routeIntentFromNativeNotification` 已覆盖 pump foreground notification 与 auto-end notification 的一次性 typed intent。`routeIntentsFromPendingStorage` 已覆盖 plan / pregnancy diary pending storage 到 badge intents。`routeIntentsFromAgentNavigationEvents` 已覆盖 Agent artifact、Schedule prefill、Device/Pump gating、Calibration auto-start 和 legacy customEvent navigation。`routeIntentsFromMediaAndIbclcInput` 已覆盖 Media Viewer 与 IBCLC start/return viewport intents。`pump_overlay_route_action.dart` 已对齐 Web 端 overlay hide/update/skip 规则和进度 clamp。`test/core/routing/route_intent_test.dart` 已对所有 route intent fixtures 断言完整 `expectedIntents` 的 type、path、payload 和 consume-once 语义。
