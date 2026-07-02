# Flutter 存储迁移清单

> 状态：Phase 0 inventory + fixtures 版  
> 目标：识别当前 Web/Capacitor 状态来源，定义 Flutter 迁移目标、用户隔离和幂等规则。  
> 原则：不要盲目迁移陈旧运行态；只迁移能校验、对用户连续体验有价值的数据。

---

## 1. 目标存储分层

| Flutter 目标层 | 用途 | 候选实现 |
|---|---|---|
| Secure storage | token、敏感鉴权材料 | `flutter_secure_storage` |
| Scoped key-value | 轻量用户配置、迁移标记 | `shared_preferences` + user scope wrapper |
| Local database | chat/history/records 离线缓存，如果确认需要 | Drift / Isar / Hive |
| Native service store | 后台泵奶、通知、overlay、native device snapshot | Android SharedPreferences / service store |
| Ephemeral memory | BLE connection、scan state、页面临时状态 | Riverpod/Bloc state |

---

## 2. 当前 Web/Capacitor storage keys

| Key | Current store | Current source | Category | Flutter target | Migrate | Rule |
|---|---|---|---|---|---|---|
| `mai_debug_user_id` | localStorage | `src/lib/debugUserConfig.ts` | runtime user | scoped key-value | yes | 迁移当前测试/运行用户；正式登录体系接入后降级为 dev-only。 |
| `mai_debug_user_stage` | localStorage | `src/lib/debugUserConfig.ts` | runtime stage | scoped key-value | yes | 仅接受合法 mom stage，非法值 fallback。 |
| `mai_debug_user_ids` | localStorage | `src/lib/debugUserConfig.ts` | dev multi-user | scoped key-value | dev-only | 仅 internal/dev 保留。 |
| `mai_anonymous_user_id` | localStorage | `src/lib/debugUserConfig.ts` | anonymous runtime user | scoped key-value | yes | 保持 demo continuity，但未来登录后不作为主身份。 |
| `mai_agent_hub_chat_messages_v1` | localStorage | `src/lib/chatMessagesLocalPersistence.ts` | chat cache | local database or scoped KV | yes, if retained | 需要定义 retention、最大条数和跨用户隔离。 |
| `mai_agent_conversation_id` | localStorage + legacy sessionStorage | `src/lib/agentConversationSession.ts` | Agent conversation | scoped key-value | yes | localStorage 为主；sessionStorage 同键只作为 legacy import，导入后删除。 |
| `momcozy_conversation_id` | localStorage | `src/lib/agentConversationSession.ts` | AG-UI thread | scoped key-value | yes | 与 Agent stream session 对齐。 |
| `calibration` | localStorage | `src/lib/calibrationLocalStorage.ts`; `src/pages/ComfortCalibration.tsx` | calibration result | scoped key-value | yes | 必须校验 left/right + stim/deep；非法/0xFF 不作为有效校准。 |
| `calibrationInProgress` | localStorage | `src/pages/ComfortCalibration.tsx` | transient calibration | none/ephemeral | no | 不迁移，Flutter 冷启动安全进入未校准或恢复确认态。 |
| `calibrationHubNotice` | localStorage | `src/pages/agentHub/agentHubConstants.ts`; `src/pages/AgentHub.tsx` | one-shot UI notice | route/event queue | maybe | 仅作为一次性 intent，迁移时只消费一次。 |
| `calibration_prompt_disabled` | localStorage | `src/pages/pumpSession/usePumpCalibrationRuntime.ts` | UX preference | scoped key-value | yes | 作为用户偏好迁移。 |
| `calibration_decline_count` | localStorage | `src/pages/pumpSession/usePumpCalibrationRuntime.ts` | UX counter | scoped key-value | yes | 非数字 fallback 0。 |
| `device_store` | localStorage + Capacitor Preferences | `src/lib/deviceStore.ts` | paired device snapshot | device repository + native state | partial | 只迁移配对信息；不要信任陈旧 `connected`。 |
| `momcozy_status_care_stage` | localStorage | `src/pages/status/StatusOverviewBody.tsx` | status UI preference | scoped key-value | yes | 仅接受 pregnancy/postpartum 等合法值。 |
| `activePlanIds` | localStorage | `src/data/planMockData.ts` | legacy/mock plan | none or dev-only | no by default | 来自 mock data，产品确认前不迁移。 |
| `currentLactationGoal` | localStorage | `src/data/planMockData.ts` | legacy/mock goal | none or dev-only | no by default | 来自 mock data，产品确认前不迁移。 |
| `volume-unit` | localStorage | `src/lib/volumeUnit.ts` | unit preference | scoped key-value | yes | 仅接受 `mL` / `oz`。 |
| `momcozy_user_id` | localStorage | `src/lib/ibclcConsult.ts` | IBCLC client user | scoped key-value | maybe | 与主 user id 关系需确认，避免双身份。 |
| `momcozy_ibclc_consult_completed` | localStorage | `src/lib/ibclcConsult.ts` | IBCLC completion | scoped key-value | maybe | 若 IBCLC 保留，则迁移。 |
| `momcozy_ibclc_consult_completions` | localStorage | `src/lib/ibclcConsult.ts` | IBCLC history | local database or scoped KV | maybe | 若 IBCLC 保留，则迁移最近记录。 |
| `momcozy_ibclc_return_to` | localStorage | `src/lib/ibclcConsult.ts` | route return | route intent queue | no/pending only | 一次性 intent，不长期迁移。 |
| `momcozy_ibclc_return_viewport` | localStorage | `src/lib/ibclcConsult.ts` | viewport restore | route intent queue | no/pending only | 仅在同次返回恢复。 |
| `mmc_background_notify_onboarding_done` | Capacitor Preferences | `src/components/system/BackgroundNotifyOnboardingGate.tsx` | onboarding flag | scoped key-value/native pref | yes | 与通知权限状态一起复核。 |
| `mmc_schedule_reminder_on` | Capacitor Preferences | `src/pages/Schedule.tsx` | schedule reminder preference | native notification prefs | yes | Android native reminder service 需要读取。 |

---

## 3. sessionStorage / ephemeral keys

| Key | Current store | Current source | Flutter target | Migrate | Rule |
|---|---|---|---|---|---|
| `pump_session_state` | sessionStorage; legacy localStorage | `src/lib/pumpSessionLifecycle.ts` | native session snapshot + state machine | no direct migration | legacy localStorage 已清理；Flutter 应从 native service snapshot 恢复。 |
| `pump_session_letdown_counts` | sessionStorage | `src/lib/pumpSessionLifecycle.ts` | pump session state machine | maybe | 只在 active session 可校验时恢复。 |
| `pump_session_process_all` | sessionStorage | `src/lib/pumpSessionProgress.ts` | pump session state machine | maybe | 只在 active session 可校验时恢复。 |
| `mmc_native_summary_body` | sessionStorage | `src/pages/AgentHub.tsx` | route/event queue | no/pending only | 消费一次后删除。 |
| `mmc_status_growth_highlight_pending` | sessionStorage | `src/lib/statusGrowthHighlight.ts` | route/event queue | no/pending only | 通知跳转高亮，一次性。 |
| `mmc_pump_auto_end_off_pump_pending` | sessionStorage | `src/lib/pumpAutoEndSession.ts` | native route/event queue | no/pending only | 只消费一次，不能长期迁移。 |
| pump completion notified flag | sessionStorage | `src/lib/pumpCompletionReminder.ts` | pump session state machine | no | 运行态，不迁移。 |

---

## 4. Notification / route pending keys

| Key | Store | Source | Target | Rule |
|---|---|---|---|---|
| `mmc_birth_journey_plan_nav_pending` | localStorage | `src/lib/planNotification.ts` | route intent queue | 一次性导航 intent。 |
| `mmc_birth_journey_plan_card_pending` | localStorage | `src/lib/planNotification.ts` | page badge/card state | 进入 Status 后消费。 |
| `mmc_milk_plan_nav_pending` | localStorage | `src/lib/planNotification.ts` | route intent queue | 一次性导航 intent。 |
| `mmc_milk_plan_schedule_pending` | localStorage | `src/lib/planNotification.ts` | Schedule page badge/card state | 进入 Schedule 后消费。 |
| `mmc_pregnancy_diary_nav_pending` | localStorage | `src/lib/pregnancyDiaryEvents.ts` | route intent queue | 一次性导航 intent。 |
| `mmc_pregnancy_diary_card_pending` | localStorage | `src/lib/pregnancyDiaryEvents.ts` | Status page card state | 进入 Status 后消费。 |
| `mmc_pregnancy_diary_card_label` | localStorage | `src/lib/pregnancyDiaryEvents.ts` | none | legacy label，迁移时清理。 |
| `mmc_milk_analysis_reminder_followup_pending` | localStorage | `src/lib/milkAnalysisReminderFollowup.ts` | background job/event queue | 需要 TTL、attempts 和 dedupe。 |

---

## 5. Android native stores

| Store/Class | Current source | Data | Flutter target | Rule |
|---|---|---|---|---|
| `DeviceNativeStateStore` | Android Java | left/right device native state | device native repository | Flutter 读取前校验，不把 stale connected 当事实。 |
| `BackgroundNotifyPrefs` | Android Java | notification config/enabled | native notification repository | Android 后台服务仍 native 时可继续作为 source of truth。 |
| `DeviceReminderWebSocketPrefs` | Android Java | WS url/token/enabled | notification/native realtime config | 迁移时优先改成 push/native fallback 策略。 |
| `NotifyAlarmPayloadStore` | Android Java | alarm payload before trigger | native notification queue | 仅 native 内部使用，Flutter 只接 route intent。 |
| `PumpAgentNativeStore` | Android Java | pump upload/session snapshot | pump native repository | 保持后台上传幂等，Flutter 只读 typed snapshot。 |

---

## 6. 迁移器要求

```text
[x] 所有迁移步骤幂等
[x] 每个 key 有合法值校验和 invalid fallback
[x] 每个 user-scoped key 必须带 user id 或通过 scoped storage wrapper 隔离
[x] 运行态 key 默认不迁移，除非能和 native active session 校验
[x] route pending key 只能消费一次
[x] legacy/mock key 默认不迁移，除非产品确认保留
[x] dry-run 输出 migration version、wouldWrite、wouldDeleteLegacyKeys、diagnostics 和 unhandledLegacyKeys
[x] 迁移失败不阻塞 dry-run，但必须记录脱敏诊断
[x] App 内真实写入迁移完成后持久化 migration version；`StorageMigrationExecutor` 在 scoped writes 和 legacy delete marker 完成后最后写入 `momcozy.storageMigration.version`
```

## 7. Phase 0 fixtures

已创建可执行迁移 fixtures：

```text
test/fixtures/storage_migration/
  p0_valid_core_state.json
  p0_invalid_values_fallback.json
  p0_one_shot_route_intents.json
  p0_pump_runtime_not_trusted_without_native_session.json
  p1_preferences_ibclc_and_multi_user.json
```

这些 fixtures 覆盖：

- 核心用户、Agent 会话、chat cache、calibration、device pairing、通知偏好。
- 非法值 fallback 和脱敏 diagnostics。
- 一次性 route/notification intent 消费。
- pump runtime key 不直接恢复的安全规则。
- P1 偏好、IBCLC 连续性和 internal/dev 多用户快照。

当前 Flutter migration runner 已读取这些 JSON，断言 `legacy` 输入能产生 `expected` 输出；dry-run CLI 可对 fixtures 或真实导出的 legacy storage JSON 生成只读报告。

App 内真实迁移使用 `core/storage_migration/storage_migration_executor.dart`：

- `applyInputIfNeeded()` 接受 fixture 结构或原始 legacy bucket export。
- 所有写入使用 `momcozy.storageMigration.v1.user.<encoded-user-id>.*` 前缀隔离。
- `momcozy.storageMigration.version` 在所有目标写入和 legacy delete marker 完成后最后写入，失败时不会误标已迁移。
- `MomCozyApiRuntime.bootstrap()` 已支持注入 `legacyStorageSnapshot` 和 `StorageMigrationTargetStore`，用于 cutover 时由原生/导出层提供真实 legacy snapshot；没有 snapshot 时不会触发迁移。

```bash
cd flutter_app
dart run tool/storage_migration_dry_run.dart
dart run tool/storage_migration_dry_run.dart path/to/legacy-storage-export.json
```
