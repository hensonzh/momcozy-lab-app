# Flutter 迁移前 Baseline Defects

> 状态：Phase 0 当前基线记录  
> 记录日期：2026-06-29  
> 目的：把迁移前已存在的失败项与后续 Flutter 迁移回归区分开。

---

## 1. 当前命令结果

| Command | Result | Notes |
|---|---|---|
| `npm run build` | pass | Vite production build 通过；存在 chunk size 和 dynamic/static import warning。 |
| `npm test` | pass | 55 个测试文件，346 个用例全部通过。 |
| `npm run lint` | pass | 0 errors / 0 warnings。 |

---

## 2. Test baseline defects

当前无阻断性 test baseline defect。以下为本轮 Phase 0 已修复项：

| ID | Owner | Source | Symptom | Severity | Decision | Tracker | Recheck |
|---|---|---|---|---|---|---|---|
| WEB-BASELINE-001 | mobile engineering | `src/lib/androidNotificationIcons.test.ts:174` | launcher portrait ratio 期望 `0.56-0.58`，旧资源实际 `0.8020833333333334`。 | P1 | 已修复 launcher PNG 资源，使 legacy icon 人物边界回到安全范围。 | `doc/flutter-baseline-defects.md#2-test-baseline-defects` | `npm test -- src/lib/androidNotificationIcons.test.ts` |
| WEB-BASELINE-002 | mobile engineering | `src/pages/status/StatusOverviewBody.render.test.tsx:440` | 测试期望固定 `demo_mama_increase_001`，运行时使用 generated runtime user id。 | P1 | 已修复测试期望，改为跟随 `DEFAULT_CHAT_USER_ID`。 | `doc/flutter-baseline-defects.md#2-test-baseline-defects` | `npm test -- src/pages/status/StatusOverviewBody.render.test.tsx` |

---

## 3. Lint baseline defects

当前无 lint error。以下为本轮 Phase 0 已修复项：

| ID | Owner | Source | Rule | Severity | Decision | Tracker | Recheck |
|---|---|---|---|---|---|---|---|
| LINT-BASELINE-001 | mobile engineering | `src/components/device/BluetoothSearchDrawer.test.tsx:11` | `@typescript-eslint/no-explicit-any` | P2 | 已修复测试 mock typing。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-002 | mobile engineering | `src/data/planMockData.ts:83` | `no-empty` | P2 | 已修复空 catch。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-003 | mobile engineering | `src/lib/ble.ts:514` | `no-async-promise-executor` | P1 | 已修复 Promise executor，保持 BLE notify 初始化后再发送的原流程。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-004 | mobile engineering | `src/lib/ble.ts:613` | `no-async-promise-executor` | P1 | 已修复 Promise executor，保持 frame retry/timeout 逻辑。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-005 | mobile engineering | `src/pages/Records.tsx:393` | `@typescript-eslint/no-explicit-any` | P2 | 已补 Recharts tick props 类型。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-006 | mobile engineering | `tailwind.config.ts:124` | `@typescript-eslint/no-require-imports` | P2 | 已改 ESM plugin import。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |
| LINT-BASELINE-007 | mobile engineering | `tailwind.config.ts:124` | `@typescript-eslint/no-require-imports` | P2 | 已改 ESM plugin import。 | `doc/flutter-baseline-defects.md#3-lint-baseline-defects` | `npm run lint` |

---

## 4. Lint warning groups

当前 `npm run lint` 已无 warning。以下为本轮 Phase 0 已收敛或显式接受的 warning 分组：

| Group | Examples | Decision |
|---|---|---|
| React hook deps | `AgentHub.tsx`, `Schedule.tsx`, pump hooks, manual entry dialogs | 已修复低风险依赖；涉及 stream callback 的场景改用 stable ref。 |
| One-shot scripted effects | `InlineMaternityFlow.tsx`, `InlineWorkFlow.tsx`, `ComfortCalibration.tsx`, `DeviceDebugDrawer.tsx` | 已用局部 eslint 说明保留现有一次性/按 tab 触发语义，避免补依赖导致重复脚本、重复请求或倒计时重置。 |
| Fast refresh only-export-components | `ChatMarkdown.tsx`, `ChatMarkdownImage.tsx`, UI primitives | 已用文件级注释标记为有意导出 helpers/variants，运行时无影响。 |

---

## 5. Build warnings

`npm run build` 通过，但有以下 warning：

- `@capacitor/core` 同时被动态和静态 import，Rollup 不会移动 chunk。
- `src/lib/ble.ts` 同时被动态和静态 import，Rollup 不会移动 chunk。
- `@capacitor/preferences` 同时被动态和静态 import，Rollup 不会移动 chunk。
- `dist/assets/index-*.js` 超过 500 kB，当前约 2.25 MB minified / 694 kB gzip。

这些不是 Flutter 迁移阻断项，但能说明当前 Web App 体量和 Capacitor coupling 较高。

---

## 6. Phase 0 exit decision

```text
[x] WEB-BASELINE-001 fixed or accepted
[x] WEB-BASELINE-002 fixed or accepted
[x] LINT-BASELINE-001..007 fixed or accepted
[x] BLE-related lint defects reviewed before BLE protocol extraction
[x] `npm run build` remains green
[x] Re-run `npm test`, `npm run lint`, and `npm run build` after baseline cleanup
```
