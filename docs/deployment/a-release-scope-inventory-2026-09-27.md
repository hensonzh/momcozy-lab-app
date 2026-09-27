# A 发布候选范围与接口依赖盘点（2026-09-27，只读快照）

**结论：不把三仓库全部未提交改动直接提交到 `main` 或打入 A。**本报告是分类和接口路径盘点，不是代码审查通过、真实 API 烟测或发布许可。本轮没有提交、推送、构建或部署。

## 1. 可追溯基线与工作区现状

| 仓库 | 本地 HEAD | 当前工作区变更路径数（含未跟踪） | 与现网关系 |
| --- | --- | ---: | --- |
| Backend | `f86abb8` | 52 | 当前服务 manifest 指向 `444844240f577a8cd0a58888a9a649eda2938bfc`，本地 HEAD 比部署点多 8 个提交 |
| Agent | `b76b37b` | 59 | 当前服务 manifest 指向 `18682adec21b463b84dd8f387989285bc0419846`，本地 HEAD 比部署点多 13 个提交 |
| App | `a5614ce1` | 334 | 多数为视觉/测试截图与产品流程改动；`pubspec.yaml` 仍为 `1.0.0+59` |

Backend、Agent 两个**已部署提交对象仍在本地 Git 历史中**，其提交中的 OpenAPI 快照与各自线上 `/openapi.json` JSON 完全一致。这给 A 提供可核验的现网协议基线，但不意味着可以直接拿最新三仓库工作区发布。以上工作区数量为检查时快照，其他协作者继续编辑后会变化。

当前本地 Backend、Agent、App 三份 Product OpenAPI 快照字节一致；但它们对照的是**尚未部署的新候选**，并非现网契约。`backend/.github/workflows/backend-delivery.yml` 和 `backend/scripts/check_deployed_openapi_compatibility.py` 中的兼容门禁改动亦未提交。

## 2. 未提交改动的候选分组（不得按整仓 `git add .`）

### A 本地发布门禁：可优先单独审查

- App：`.github/workflows/app-staging-release.yml`、`scripts/run-flutter-release-gate.mjs`、`scripts/build-flutter-app.sh`、`scripts/build-flutter-apk-download-site.mjs`、`scripts/flutter-api-config.mjs`、`scripts/tests/test_legacy_invite_release_lane.py`、`test/features/auth/release_lane_auth_mode_test.dart` 及相关现有脚本测试。这组锁定 A 的 URL、邀请码编译参数、发布签名和预构建 APK 校验。工作流文件还含其他协作者的 smoke-infant 重构，提交前必须逐 hunk 审查。
- Backend：若 A **需要新 Backend 部署**，兼容检查脚本、对应测试和 delivery workflow 的兼容门禁可单独审查；它们不能代替业务兼容修复。
- Agent：若 A 沿用现网 Agent，不要为“凑三仓发布”部署一个并无必要的新 Agent。若必须更新，先对照现网 Agent API 与 Product 契约。

### B 专属预检：不作为 A 业务升级依赖

- Backend、Agent：各自的 `config/release-targets/north-america-staging.json.example`、`scripts/check_release_target.py`、`scripts/release.py` 的 target 拒绝门禁、相应测试及 `.gitignore`。这些只是拒绝误部署 B，并没有托管存储 Compose 或 B 运行环境。
- App：`config/release-lanes/north-america-staging.json.example`、`scripts/check-north-america-staging-target.mjs`、`scripts/tests/test_north_america_staging_target.py`、`scripts/tests/test_store_release_lane.py`。`scripts/build-mobile-app.mjs` 同时含 A/B 分支，不能把整个文件简单归作 A 或 B。B 真正构建仍故意失败。

### 需产品范围和兼容决策的混合改动：本次暂不自动纳入

- Backend：`app/modules/auth/*` 的邮箱验证码、密码变更及请求 schema；`app/modules/onboarding/*` 和 `app/modules/profiles/*` 的当前分娩/喂养资料；`app/modules/notifications/*`、`app/api/v1/router.py`、新 Agent 批量回执与迁移。对应测试、生成 OpenAPI、契约文档必须跟其业务代码一起审查，不能独立挑选某一份生成文件。
- Agent：乳量评估 skill/提示词、schedule/record 工具、通知派发、runtime/ledger/model/迁移及产品契约快照。当前候选还移除了现网 care-reports 内部操作；不能把这些未提交功能默认视为 A 所需。
- App：`lib/core/auth/*`、`lib/features/auth/*` 混合邀请登录与 B 邮箱流程；`lib/features/onboarding/*`、`lib/modules/baby/*`、`lib/modules/mom/*`、`lib/features/agent_hub/*` 带来新 API 或产品体验变化；对应 Widget/golden 与 `docs/backend-contract/*` 需同源审查。`test/` 下 279 条路径中大量为截图/golden，不应因数量大而默认纳入 A。
- 各仓库其余文档、评测、设计图片、未跟踪文件先保留原样，由负责人确认用途；任何含密钥的私有 env/签名文件均不进入 Git。

## 3. App → 线上 API 依赖矩阵

以下是 App 当前 `flutter-smoke-flows.json` 中 6 条流程、27 个步骤对**现有公开 OpenAPI 路径+方法**的静态比对；不代表请求体、鉴权、行为或真实设备已经通过。`${id}` 已归一化为 OpenAPI 的 `{id}`，查询参数不当作路径。

| 流程/能力 | 当前 A 现网 | A 发布影响 |
| --- | --- | --- |
| 邀请码登录、refresh、logout（3 步） | 路径/方法均存在 | 核心 A 登录路由可继续验请求/响应及设备绑定；不能由此推断新 APK 已通过 |
| 当前分娩资料 onboarding（4 步） | `GET /v1/onboarding/me` 和 `PUT /v1/onboarding/me/profile` 均不存在；流程中 3 步缺失 | **Fresh-user App 阻断**。App 当前 HEAD 的 `onboarding_api_repository.dart` 已使用这些接口；不能简单只发最新 App 而保持 Backend 不变 |
| records/schedule/files（4 步） | 路径/方法均存在 | 仍需 schema/权限/数据行为对照 |
| Agent replay（6 步） | `GET /v1/agent/threads/{thread_id}/history` 不存在，其余路径/方法存在 | 判断 A 客户端是否必须依赖 history；若需新 Agent，先保留现网旧操作 |
| voice contract（2 步） | 路径/方法均存在 | 仍需设备端语音能力验收 |
| 邮箱注册/找回/密码（8 步） | `POST /v1/auth/verify-registration-code`、`POST /v1/auth/change-password` 不存在 | 主要属于 B 正常账号流程；不可误当作 A 邀请码链路的上线前提 |

当前候选 Product OpenAPI 有 95 条路径、115 个 HTTP 操作；A 现网有 153 条路径、181 个操作。以现网为旧版本运行兼容检查得到 **80 项**：75 个操作被候选删除、2 个请求新增必填 `confirm_password`、3 个 `/v1/schedule` 成功响应字段消失。Agent 候选另缺现网 2 个内部 care-report 操作。不能只看“总路径数”或为了上线关闭检查。

## 4. 推荐发布切片及待确认边界

1. **先固定 A 业务范围。**A 保留现有服务器、数据、已安装客户端和邀请码登录；本次是否需要新的 onboarding 与 Agent history，必须由 App 路由/真实安装流程评审。若仅做最小邀请制内测，也要给 fresh user 提供与现网契约兼容的 onboarding 路径。
2. **选择兼容实现，而不是把全部 WIP 打包。**可从已部署提交和线上契约出发做 A 专用的增量适配，或在新候选中补齐旧路由/旧请求与响应兼容；两条路都需明确 CI、数据库迁移、回滚与当前 `test` 部署拓扑的发布边界。不得复制旧 OpenAPI 伪装兼容、改 manifest 名字或删老接口来规避检查。
3. **选定候选后再分组提交** A 所需 Backend/Agent/App 源码、测试、对应生成契约；未完成 B 和其他产品开发留在原工作区/独立分支。先对全套测试与在线兼容门禁取证，再另行确认 push、真实部署、Android release signing、build number 与 APK 分发。

已部署 `test` 与仓库新 `staging` 仍未切换；旧邀请码管理页按用户决定不做专项隔离/密钥轮换。本报告不改变这些决策。参见 [A 发布前检查](a-release-preflight-2026-09-27.md)。
