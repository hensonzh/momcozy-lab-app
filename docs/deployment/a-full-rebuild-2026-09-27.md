# A 链路全新空数据重建与发布交接（2026-09-27）

状态：**旧应用已停止、备份已校验；新服务尚未上线，新 APK/二维码尚未发布。** 此页是可复核的发布记录与待办，不是旧 API 兼容迁移方案。A 保留新加坡同一主机、现有 Product/Agent HTTPS 域名与 App staging CA；以三仓库的新版源码和全新空 PostgreSQL、Redis、MinIO 为准。B 北美链路不在本次范围。

## 现场与保留边界

- 已停止 23 个应用容器（含独立 `consultation`）；SSH、Docker、Nginx 与数据卷保留。重新核对 `docker ps` 为零，绝不把容器重启当作新部署。`consultation` 没有这三仓库对应的新发布链，维持停机。
- 停机前容器清单：`/opt/momcozy-lab/backups/app-containers-prestop-20260927T095400Z.json`（0600）；8 个旧卷离线归档：`/opt/momcozy-lab/backups/offline-volumes-20260927T095705Z/manifest.json`（SHA-256 与 tar 读取已校验）；原卷和旧 release 指针留在 `/opt/momcozy-lab`，不迁入新环境、不删除。
- 新 A 使用独立 `/opt/momcozy-lab-staging`，Compose project 为 `momcozy-lab-backend-staging` / `momcozy-lab-agent-staging`，网络 `momcozy-lab-staging`，由新项目首次创建独立卷。旧 project/卷、manifest `test` 和旧数据库不作为回滚目标。
- 仍走 `backend-test` → `127.0.0.1:8001`、`agent-test` → `127.0.0.1:8002`，公网 HTTPS 均为 8443；新的活动 manifest 必须是 `staging`。首次空 root 没有旧 OpenAPI 可比；后续同一新 root 的替换仍强制做在线兼容检查。

## 提交与门禁

1. 以 Backend、Agent、App 三仓库 **所有未提交代码和资源**为候选，提交到各自 `release/a-full-rebuild-20260927`；App build 号单独保留为 `1.0.0+60`。在发布前核查当前 HEAD、工作区、目标 tag `staging-android-v1.0.0-60` 是否未占用；若又有 App 新提交，以最新提交重跑门禁并构建，绝不重用旧 build 57 debug APK。
2. Backend 运行 Ruff/Mypy/Pytest/Alembic heads 与离线 SQL，Agent 运行 Ruff/Pytest/Alembic heads；App 运行格式/分析、脚本和契约校验、包装/安全检查、非 golden 与 golden 测试。CI 要在推送后的 `main` 对**精确 SHA**生成可核验的 GHCR 镜像 digest；不打包未提交文件，不跳过失败门禁。
3. GitHub `staging` Environment 目前没有环境级变量/密钥。工作流可复用仓库的 `STAGING_SSH_*` 和 `STAGING_APPROVERS`（生产环境不回退到 staging 密钥）；仍需为 Backend、Agent 设置 `RELEASE_ROOT=/opt/momcozy-lab-staging`、各自 `SERVICE_ENV_FILE=.../shared/{backend,agent}/staging.env`、共同 `RELEASE_LOCK_PATH=.../shared/staging-release.lock`、分别配置现有 `PUBLIC_URL` 和已审阅的 `CA_FILE`。App 需要同一 `RELEASE_ROOT`、`RELEASE_LOCK_PATH`。如需编辑远端配置或推送私有仓库，先单独确认。

## 私有配置与部署顺序（待执行）

1. 在新 root 下创建 mode-0600 的 Backend、Agent `staging.env`，依各自唯一 `env/staging.env.example` 填写，**不打印或提交任何密钥**。只复用经确认的第三方 provider 设置；新 PostgreSQL/Redis/MinIO 凭据、JWT 私钥、邮箱 token key、跨服务 key、邀请码均需按新栈生成并在两份 env 中对齐。A 的邀请码登录不依赖 B 的 Resend 完成，但邮件注册/重置不应伪称已打通。Backend 是共享三件套 owner；Agent 不创建第二套。`SERVICE_API_KEY` 网页暴露风险按既有用户决定暂不实施专项隔离，仍须如实提示。
2. 将公共 staging CA 放在主机只读路径并将该路径作为两工作流 `CA_FILE`；核对与 App 内 CA 匹配。用受保护 workflow：先 `backend-delivery` 的 `bootstrap`（空 PostgreSQL/Redis/MinIO），再 `deploy`（迁移、健康、manifest），最后 `agent-delivery` 的 `deploy`（匹配 Product 契约、Agent 迁移、worker heartbeat、健康）。部署失败时新服务停住、保留新数据与诊断，不自动重启旧容器或回灌旧卷。
3. 验证两条公开 `/v1/health/ready` 和 `/openapi.json`、活动 manifest 的 SHA/image digest/environment、邀请码创建/登录/禁用和设备绑定；避免在日志打印邀请码或 access token。`/v1/admin/invite-codes/ui` 为现有邀请码管理页（无独立操作员鉴权且前端嵌入 service key），不能声称风险已经修复。
4. 后端 join barrier 通过后运行 `app-staging-release.yml`：最新 App main SHA、正确 Backend/Agent manifest、签名/证书身份、staging flavor、`MOMCOZY_INTERNAL_INVITE_LOGIN=true`、在线 Product-Agent smoke 全部通过才上传 APK，并更新 `hensonzh/momcozy-lab-releases` 的 `/staging/` 下载页、SHA256、二维码与 provenance。再核对 Pages manifest 与 Release APK 的字节数和 SHA256，手机安装、扫码和邀请码登录人工验收。

预期入口（**上线前不可当作已可用**）：下载页 `https://hensonzh.github.io/momcozy-lab-releases/staging/`；邀请码后台 `https://backend-test.lute-momcozylab.luteos.cloud:8443/v1/admin/invite-codes/ui`。最终报告必须给实际 APK 直链、二维码链接、校验和、三仓库 SHA、镜像 digest、迁移 head、健康/worker 状态以及未完成的真机风险。不触碰现有 iOS 证书、profile 或设备。
