# A 链路实际发布前检查（2026-09-27）

状态：**停止在只读预检，尚未构建、推送、部署或发布**。此记录不是上线批准。

## 现场证据

- `app/config/environments/staging.json` 指向现有 Product/Agent HTTPS 域名；两边 `/v1/health/ready` 和 `/openapi.json` 均返回 200（使用 App 内的 staging CA 验证）。
- 现有服务器 `/opt/momcozy-lab/current/{backend,agent}/release-manifest.json` 的 `environment` 均为 `test`，而当前三仓库发布 workflow/脚本要求 `staging`。不能靠改 manifest 字段或直接迁移现有数据库解除此约束。
- 线上 Product OpenAPI 有 153 条 path，当前 Backend 候选快照有 95 条。`backend/scripts/check_deployed_openapi_compatibility.py` 对现网与候选返回失败，报告 80 项不兼容（75 个旧操作消失、2 个新增必填字段、3 个响应字段消失；命令输出另有 1 行标题）。线上 Agent OpenAPI 与候选也不同。**不可关闭兼容门禁直接替换 A。**
- 本地 Backend、Agent、App 锁定的 Product OpenAPI 快照已字节一致，但这不表示与 A 现网一致。
- Backend、Agent、App 工作区分别有大量未提交变更；Backend、App 的 `main` 也分别领先 `origin/main`。仓库当前 workflow 依赖受 CI 验证的已推送 main 提交，不能把工作区的未提交改动直接打包上线。
- App 当前 `version: 1.0.0+59`；此前公开下载仓库已有 `unified-android-v1.0.0-59`。新发布须先预留新的 build number、重新核查 tag、单独提交版本变更。
- 本机旧 `app-staging-release.apk` 是 build 57、`com.momcozymai.app.flutterpoc.staging`，Android Debug 证书签名；不能作为 A 新包签名/邀请码模式验收。
- 按用户决定，不对旧邀请码管理页实施专项隔离或 `SERVICE_API_KEY` 轮换；不可把它描述为已修复。

## 恢复发布的顺序

1. 明确 A 保留当前 `test` 运行拓扑还是审核迁移到新的 `staging` 发布拓扑；两者不可混用 root、私有 env、manifest、备份/回滚方案。
2. 选择 Backend/Agent/App 干净提交作为 A 候选，保留现网历史 API；解决契约兼容性差异并通过仓库测试和在线对照，不打包旁人的未提交工作。
3. 确认推送、CI 镜像、签名、build number、发布仓库/GitHub Environment 权限；不要在同一动作中偷偷改 iOS 证书/profile、设备、DNS 或旧管理页。
4. 分别批准并执行 A Backend/Agent 部署与新 APK 构建；两份活动 manifest、live OpenAPI/健康、邀请码登录烟测和新包签名都通过后，才开放 APK 下载页/二维码，并做真实设备安装验收。

本轮只读查询了公开 API、GitHub Release 元数据与服务器 release manifest。所有 tag、远端状态及配置在实际发布前需要重查。
