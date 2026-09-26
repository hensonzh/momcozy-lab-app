# iOS staging TestFlight Build 59 — 外部测试暂停交接

> 记录日期：2026-09-26。此文记录暂停时的**实际进度**，不是正式 App Store 上架清单。
> 用户要求停在这里留档；不要以本文作为提交审核、开放链接或邀请测试员的授权。
> iOS 历史规划见 [`ios-app-store-handoff.md`](ios-app-store-handoff.md)；其中 2026-09-24 的“不能上传”等判断已经过时。

## 目标与边界

- 目标：让非 App Store Connect 团队成员通过 **TestFlight** 安装、登录并体验 iOS staging App；目标受众是北美用户。
- 用户已改变最初的“仅邮箱定向邀请”方案，**确认未来启用公开邀请链接**。链接可能被转发，Apple 的公开链接条件不提供国家/地区过滤，不能宣称技术上只允许北美用户安装。
- 用户要求：需要关键操作时先确认；**不操作现有证书或 provisioning profile，不添加设备**。尤其在提交 Beta App Review、实际开启/传播公开链接、改变出口合规回答之前，逐项核对并征求确认。
- 不要把 TestFlight 外测审核与正式 App Store 上架审核混为一谈；本阶段不做正式上架。

## 已完成并核验

| 项目 | 状态 |
| --- | --- |
| Apple Developer Team | `YP9F4937J4` |
| Staging Bundle ID | `com.momcozy.mai.staging`，与 App Store Connect App ID `6816097872` 匹配 |
| 签名 | 为此次 staging 流程新建 Apple Distribution 证书 `MR8YBZQBLK` 和 App Store profile `4VNZA4X2H2`；未改动既有资源、未注册设备 |
| Build 58 | `TestFlight Internal Only` 技术验证包，**不可**用于外测 |
| Build 59 | `1.0.0 (59)`，普通 App Store Connect 导出（`testFlightInternalTestingOnly=false`），已上传且 Apple 处理完成；2026-09-26 在 TestFlight 显示“准备提交”，尚未进入外测审核 |
| Build 59 构建源 | `app` 提交 `16533f1782da6363e8cc14383ba7d4f66d3a6c37`；之前有回归测试修正提交 `1457e710…` 和候选基线 `edabcb10…`；**不要把之后工作区改动当作 Build 59 内容** |
| IPA | `build/ios/ipa/momcozy-ai-ios-staging-external-1.0.0-59/momcozy_flutter_app.ipa`（相对 `app/`）；SHA-256 `79918ce68c90537cfd145e82ae22dec3541dc78d949364bb6f8b4ae82271f1c1` |
| 本地质量门禁 | 当时 `flutter analyze --no-pub`、安全/隐私检查通过；799 项非视觉测试通过；完整套件仍有 29 项截图基线失败，**未**批量接受基线 |
| 上传警告 | PDFium/WebRTC 缺少 dSYM 的警告；上传成功不代表符号化完整 |
| 加密问卷 | Build 59 已按此前“标准加密算法、不在法国分发”口径填写并显示“准备提交”；**公开链接可跨地区转发，必须重新评估这个口径，不能自动沿用** |

已存在两个 TestFlight 群组，均在 2026-09-26 观察为 **0 个测试员、0 个构建版本**：

- 内部前置组：`Momcozy AI Internal Prerequisite`（`929d6847-00cb-4c59-b492-c806ee388be9`），自动分发关闭。
- 外部组：`Momcozy AI North America Beta`（`62842f73-8b67-4c1f-b6fd-8c583b172e0c`）。群组名称仅表示目标受众，不是地理封锁。

## 当前未完成／未保存

1. **TestFlight“测试信息”尚未保存。** Beta App 描述、反馈邮箱、审核联系人、登录信息、审核备注需要最终填写。用户已确认反馈邮箱与审核联系人邮箱为同一个地址、联系人为 Henson Zhang 并提供了电话；为避免将个人联系方式提交到源码仓库，本文不保存明文，填写时向用户核对。页面曾被局部编辑但未保存；不要把页面暂存值当成已提交资料。
2. **审核专用 App 账号尚未确认/创建。** 这是供 Apple 审核人员登录 **Momcozy AI staging App** 的邮箱/密码，不是 Apple Developer 或 App Store Connect 账号。应使用已完成邮箱验证、能实际登录 staging 服务、只含合成数据、无需无法执行的 MFA/验证码步骤的专用账号。仓库中 `backend/scripts/seed_local_test_account.py` 明确只适用于 `APP_ENV=local`，不是云端审核账号。密码不得写入本文、仓库或聊天；到 App Store Connect 页面由用户自行输入。
3. Build 59 **尚未加入外部组**、**尚未提交 Beta App Review**，Apple 也尚未批准外测。
4. 公开邀请链接**尚未创建/启用/传播**；当前没有可供非团队成员安装的 TestFlight 邀请入口。人数上限及设备/系统条件尚未决定。
5. 尚未由一位非团队成员验证“打开公开链接 → 在 TestFlight 安装 → 完成 App 登录 → 可体验核心功能”。上传成功或审核提交均不等于外部分发完成。

## 继续时的安全顺序

1. `cd app && git status --short --branch && git log -5 --oneline`，核对工作区和 Build 59 的候选提交；**不要**清理/覆盖后续未提交的 App 与测试改动，也不要用它们重写 Build 59 的来源记录。
2. 只读复核 App Store Connect 的 Build 59、两群组、加密合规状态与“测试信息”是否真的已保存；不要依赖本文历史快照。
3. 向用户核对英文 Beta 描述、反馈邮箱/审核联系人、隐私政策 URL 是否由业务/法务批准；落实可用的合成数据审核账号，并让用户直接在官方页面输入密码。保存前检查全部字段。
4. **先**与用户重新核对公开链接跨地区传播对“未在法国分发”出口合规回答的影响；需要改变问卷或提交材料时停下确认，必要时交法务/出口合规负责人判断，不猜答案。
5. 审核资料与合规口径确认后，选择 Build **59** 加入外部组；如果 UI 提示可能同时触发提审，先停下。单独征求用户对提交 **TestFlight Beta App Review** 的确认。
6. Apple 批准之后，再根据 UI 确定公开链接的测试人数上限/条件，操作前确认；不要把链接误当作北美地域限制，也不要未经确认公开传播。最后请非团队成员实测安装和登录。

**停止点：** 此次留档不在 App Store Connect 保存不完整的表单，不提交审核，不开放链接，不邀请测试员，不变更证书/profile/设备。
