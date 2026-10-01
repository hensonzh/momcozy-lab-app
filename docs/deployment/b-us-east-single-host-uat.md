# B 发布链路：美东单机自托管 Compose 策略

决策日期：2026-09-30。此文替代 [旧版双链路设计稿](dual-staging-release-lanes.md)
中关于 B 使用 Kubernetes、托管 RDS/Redis/S3 的部署方案。**这是部署策略与
切换计划，不代表 B 已经上线**；Backend、Agent 的 B 发布 CLI 仍保持拒绝。
A 链路保持原样，App 的 B 分发/商店策略不因服务端改用单机而改变。

## 边界与拓扑

```text
GitHub dev -> B 验证/镜像发布 -> GHCR digest -> B 目标机发布入口（尚未接通）
  B 专属发布目录/锁、私有 env、Docker Compose 项目/网络/卷
  Backend 项目: PostgreSQL + Redis + MinIO + Product API
                + 通知 worker + 邮件 worker + 一次性迁移任务
  Agent 项目:   Agent API + Agent worker + 一次性迁移任务
                └─ 加入 Backend 创建的 B 网络，使用 B 的共享基础设施
  B HTTPS 反向代理: 两个独立 API 域名 -> 对应 loopback 端口
  B 邮件 worker: 出站 Resend SMTP；Agent worker: 出站模型 API
```

- **不复用 A**：主机/发布 root/锁、私有 env、Compose project、网络、
  PostgreSQL/Redis/MinIO 命名卷、API 端口和 TLS 域名均独立。仅 API 经反向
  代理对外服务；状态服务不直接对公网开放。不能把 B 伪装成 A 的 `staging`
  或 `production` 目标。应用 `APP_ENV=staging` 是进程模式，不代表发布目标。
- **PostgreSQL**：B 单机自启动一个 PostgreSQL 实例；同实例内 Product
  使用 `momcozy_lab_backend_uat`，Agent 使用 `momcozy_lab_agent_uat`，
  两套角色/权限与 Alembic 迁移独立。此前由 IT 在托管 RDS 建过同名库，
  **新自托管库并不自动继承其数据或密码**；先确认是否需导入并制定迁移方案。
- **Redis**：B 自启动一个 Redis；Product/Agent 均使用 DB 0，沿用现有
  Product `rate-limit:*`/`product:*` 与 Agent `agent-runtime:*`/
  `momcozy-agent-runtime:*` 键前缀。不同前缀防键名冲突，不等于权限隔离；
  B 专属 ACL 只授权各自键/频道并禁止服务身份切换 DB，Redis ACL 无数据库级
  权限边界。分别验证 Lua、Stream 和锁。
- **MinIO**：B 自启动一个 S3 兼容 MinIO 服务，Product/Agent 各一个
  私有 Bucket、各自身份与桶策略。Bucket 最终名称由运维确认。使用 B
  专属卷、备份与恢复；不再依赖托管 S3、之前单对 AK/SK 或 A 的 MinIO。
- **Agent 10 并发**：B 的单 worker 目标为批量认领 10、并行处理 10 个
  run；A 保留 2 的部署配置。10 run 不等于已经通过压测。按同机资源
  配额（含 DB/Redis/MinIO）、CPU/RSS、DB 连接、模型额度、队列等待
  和 OOM 结果确定 worker 内存/CPU 限制、副本数及服务器容量。

## 发布顺序和门禁

1. 固定美东目标机和 B 域名/公网证书/反代端口；核对 B 流水线从 GitHub `dev` 拉取、使用 `deploy/Dockerfile`，标记 commit 和镜像 digest。
2. 实现 B 专属 Compose/私有 env/发布 root 和锁、初始化 DB/ACL/Bucket、
   非公网网络与卷；建立并演练两个数据库、MinIO 和 Redis 的备份恢复。
   **B Compose 模板、只读私有 env 预检和 GitHub `dev` 的验证已通过；B 镜像发布与目标机服务部署是两道独立门禁**。目标机发布入口尚未接通，不得拿 A 的部署脚本修改几个 URL 直接使用。
3. 数据处置：托管 RDS/Redis/S3 不再作为目标；是否需要保留/搬运旧数据
   需先确认。空库才按 Product -> Agent 顺序做迁移；逐项检查版本和
   schema。迁移前备份，失败则停止发布，不自动降级数据库。
4. 启动 Product API/通知 worker/邮件 worker，验证健康及注册邮件；再启动
   Agent API/worker，检查心跳和跨服务调用，做 10 run 并发压测。
5. 最后构建 B App，确认 API URL、邮箱登录、签名和分发渠道，用合成账号
   验证端到端；A/B 的镜像、数据、备份与回滚均需独立验收。

## 本轮代码变更边界

保留 B 专属 `deploy/Dockerfile`、非密钥 `deploy/config_us-east-uat`、
`release-source.json`、B 专属 Compose/私有 env 模板与目标静态校验；
删除已失效的 B Kubernetes `workloads.yaml`/`migration-job.yaml`。旧版 IT Kubernetes/托管资源申请表
仅作历史记录，**不得继续作为当前申请或发布清单**。B 专属 CI 的验证任务覆盖合成 PostgreSQL/Redis 隔离、两库合成 dump/隔离恢复、Compose 静态渲染及 Dockerfile 构建；验证成功后的独立任务仅在 GitHub `dev` push 时向私有 GHCR 发布 B 镜像并记录 digest，**不连接目标机、不执行部署**。Backend/Agent 有 B 私有目录占位文件初始化工具与只读发布准入预检；Backend 还有跨服务凭据匹配、实时数据库 revision 回滚预检和 PostgreSQL 两库恢复脚本。目标机 root/锁/0600 占位配置已准备，但真实 URL/密钥未填写；MinIO/Redis 的真实备份与隔离恢复、离机留存、可执行 B 发布/回滚 runner 与上线验收仍未完成。合成恢复不能当作目标机真实恢复。

## 目标机准备进度（2026-10-01）

- 已经通过 JumpServer 验证 B 专属主机 `32.199.186.149`（`ubuntu@ip-172-31-29-24`），
  16 vCPU／61 GiB 内存；`/data` 为独立的 200 GiB XFS 卷。已安装 Docker Engine 29.8.2
  与 Compose 5.5.1，并将 Docker/containerd 数据根放在 `/data/momcozy-lab-us-east-uat/`。
- 已建立 `/opt/momcozy-lab-us-east-uat` 的 0700 发布布局，两个服务独立的 0600
  env/目标 JSON 占位文件，以及 B 专属锁；备份目录通过持久 bind mount 映射到 `/data`。
  Backend 的 PostgreSQL 恢复脚本增加挂载源检查，避免挂载消失时写入根盘；
  `/data` 同时承载状态卷与备份，**不是异地备份**，仍需独立留存和恢复演练。
- 目标机已从 GitHub `dev` 拉取 Backend/Agent 已提交的干净快照；最新检出的提交分别是
  Backend `62ea6c0d29620d0ed07483c79abf80f3be58847a`、Agent
  `a689e662a21e91bcb95d4180e671cd5869c94154`，各自的 B 验证 CI 已通过。目标机已
  构建对应 B 镜像及固定 MinIO 源码镜像，PostgreSQL/Redis 无持久卷隔离测试通过。目标机上的镜像仍是本地构建，
  没有从私有 GHCR 拉取并验证不可变 digest，也没有切换 `current`。业务容器数为 0。
- 两份 env 仍有 `REPLACE_WITH` 和无效示例域名；目标 JSON 的 URL 仍是 `TBD`。预检
  按预期拒绝，**尚未部署** PostgreSQL、Redis、MinIO、Product、Agent 或反向代理。
  仍需确认历史数据是否迁入，批准两个 HTTPS 域名/DNS/TLS，配置 B 专属密钥。
  主机到 Resend 587、OpenAI 443 和 GHCR 443 的 TCP 连通测试通过，但真实邮件/模型
  认证与调用未验证。完成 MinIO/Redis 真实备份与隔离恢复及离机留存，提供可审核的 B 发布/回滚
  入口，最后完成真实服务、邮件和 Agent 10 并发验收。不得绕过这些门禁。

## B 镜像发布任务（与目标机部署分离）

Backend/Agent 的 B 验证 workflow 在 GitHub `dev` **push 且验证任务成功**后，另起
`b-image` 任务从各自 `deploy/Dockerfile` 构建，发布到私有 GHCR 的
`b-dev-<完整 commit SHA>` 标签，并记录不可变 digest。PR／手动 workflow 派发只验证，
不发布镜像。CI 不 SSH 目标机、不启动服务、不切换 `current`；目标机尚未配置私有 GHCR 拉取身份或拉取并核验 digest。镜像发布成功不代表
B 服务已部署或可对外使用。实际部署仍须先验证目标机私有配置、域名/TLS、
历史数据处置及 PostgreSQL/MinIO/Redis 的备份与隔离恢复门禁。
