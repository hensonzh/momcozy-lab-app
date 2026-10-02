# B 发布链路：美东单机自托管 Compose 策略

决策日期：2026-09-30。此文替代 [旧版双链路设计稿](dual-staging-release-lanes.md)
中关于 B 使用 Kubernetes、托管 RDS/Redis/S3 的部署方案。**这是部署策略与
切换计划，不代表 B 已经上线**；Backend、Agent 的 B 发布 CLI 仍保持拒绝。
A 链路保持原样，App 的 B 分发/商店策略不因服务端改用单机而改变。

## 边界与拓扑

```text
GitHub dev -> B 验证/镜像 digest 核验 -> 目标机首次发布入口（未在目标机验收）
  B 专属发布目录/锁、私有 env、Docker Compose 项目/网络/卷
  Backend 项目: PostgreSQL + Redis + MinIO + Product API
                + 通知 worker + 邮件 worker + 一次性迁移任务
  Agent 项目:   Agent API + Agent worker + 一次性迁移任务
                └─ 加入 Backend 创建的 B 网络，使用 B 的共享基础设施
  B HTTPS 反向代理: 两个独立 API 域名 -> 127.0.0.1:8001 / :8002
  B 邮件 worker: 出站 Resend SMTP；Agent worker: 出站模型 API
```

- **不复用 A**：主机/发布 root/锁、私有 env、Compose project、网络、
  PostgreSQL/Redis/MinIO 命名卷、API 端口和 TLS 域名均独立。仅 API 经反向
  代理对外服务；状态服务不直接对公网开放。不能把 B 伪装成 A 的 `staging`
  或 `production` 目标。应用 `APP_ENV=staging` 是进程模式，不代表发布目标。
- **B API 域名（2026-10-01）**：Product
  `https://backend-us-dev.lute-momcozylab.luteos.cloud`，Agent
  `https://agent-us-dev.lute-momcozylab.luteos.cloud`；两条 DNS A 记录
  均指向 `32.199.186.149`。2026-10-01 对目标实例所绑定安全组的只读检查
  发现 TCP 80/443 没有匹配的入站规则；目标机临时监听这两个端口时，外部仍超时。
  两端到 :443 均超时；反向代理、证书、入口放行与
  HTTPS 健康检查尚未完成。域名中的 `dev` 不改变 B 的
  `deployment_target=north-america-staging`、`APP_ENV=staging` 身份。
  Backend/Agent 的 `deploy/us-east-uat/nginx-*.conf` 是 B 独立的待安装
  反代模板（端口分别转 `127.0.0.1:8001` / `:8002`）；仅用合成证书做过
  Nginx 语法检验，**目标机尚无公网证书、未启用反代**。
- **PostgreSQL**：B 单机自启动一个 PostgreSQL 实例；同实例内 Product
  使用 `momcozy_lab_backend_uat`，Agent 使用 `momcozy_lab_agent_uat`，
  两套角色/权限与 Alembic 迁移独立。此前由 IT 在托管 RDS 建过同名库，
  **新自托管库不继承其数据或密码**。2026-10-01 已确认：原托管
  RDS、Redis、S3 的历史数据均**不迁入**；B 从新卷/空库/空桶初始化，
  不连接旧托管资源，不自动删除旧资源。
- **Redis**：B 自启动一个 Redis；Product/Agent 均使用 DB 0，沿用现有
  Product `rate-limit:*`/`product:*` 与 Agent `agent-runtime:*`/
  `momcozy-agent-runtime:*` 键前缀。不同前缀防键名冲突，不等于权限隔离；
  B 专属 ACL 只授权各自键/频道并禁止服务身份切换 DB，Redis ACL 无数据库级
  权限边界。分别验证 Lua、Stream 和锁。
- **MinIO**：B 自启动一个 S3 兼容 MinIO 服务，Product/Agent 各一个
  私有 Bucket、各自身份与桶策略。桶名固定为
  `momcozy-product-us-east-uat`、`momcozy-agent-us-east-uat`，首次部署前仍需目标机核验。使用 B
  专属卷、备份与恢复；不再依赖托管 S3、之前单对 AK/SK 或 A 的 MinIO。
- **Agent 10 并发**：B 的单 worker 目标为批量认领 10、并行处理 10 个
  run；A 保留 2 的部署配置。10 run 不等于已经通过压测。按同机资源
  配额（含 DB/Redis/MinIO）、CPU/RSS、DB 连接、模型额度、队列等待
  和 OOM 结果确定 worker 内存/CPU 限制、副本数及服务器容量。

## 发布顺序和门禁

1. 固定美东目标机和 B 域名/公网证书/反代端口；核对 B 流水线从 GitHub `dev` 拉取、使用 `deploy/Dockerfile`，标记 commit 和镜像 digest。
2. 实现 B 专属 Compose/私有 env/发布 root 和锁、初始化 DB/ACL/Bucket、
   非公网网络与卷；建立并演练两个数据库、MinIO 和 Redis 的备份恢复。
   **B Compose 模板、只读私有 env 预检和 GitHub `dev` 的验证已通过；B 镜像发布与目标机服务部署是两道独立门禁**。首次发布入口已有代码但未在目标机执行/验收；更新和回滚 runner 仍未实现。不得拿 A 的部署脚本修改几个 URL 直接使用。
3. 数据处置已确认：不迁移原托管数据。首次初始化前执行 Backend 的只读
   `scripts/check_b_fresh_bootstrap.py`，B 命名或 Compose 标签的卷、网络、
   容器（含已停止）存在就中止人工复核，不 prune、不覆盖。目标机于
   2026-10-01 检查时这些资源均不存在；检查不证明所有未标记磁盘目录为空。
   在密钥和恢复条件满足后，对**新库**按 Product -> Agent 顺序执行
   Alembic schema 迁移；后续 schema 变更须先备份，失败就停止发布，
   不自动降级数据库。
4. 启动 Product API/通知 worker/邮件 worker，核验公网 ready；再启动
   Agent API/worker，核验公网 ready。注册邮件、模型服务及 10-run 压测
   分别验收，不以外部提供商的单点故障阻塞 App 构建。
5. 最后构建 B App，确认 API URL、邮箱登录、签名和分发渠道，用合成账号
   验证端到端；A/B 的镜像、数据、备份与回滚均需独立验收。

## 本轮代码变更边界

保留 B 专属 `deploy/Dockerfile`、非密钥 `deploy/config_us-east-uat`、
`release-source.json`、B 专属 Compose/私有 env 模板与目标静态校验；
删除已失效的 B Kubernetes `workloads.yaml`/`migration-job.yaml`。旧版 IT Kubernetes/托管资源申请表
仅作历史记录，**不得继续作为当前申请或发布清单**。B 专属 CI 的验证任务覆盖合成 PostgreSQL/Redis 隔离、两库合成 dump/隔离恢复、Redis RDB 与 MinIO 两桶合成隔离恢复、Compose 静态渲染及 Dockerfile 构建；验证成功后的独立任务仅在 GitHub `dev` push 时向私有 GHCR 发布 B 镜像并记录 digest，**不连接目标机、不执行部署**。Backend/Agent 有 B 私有目录占位文件初始化工具与只读发布准入预检；Backend 还有跨服务凭据匹配、实时数据库 revision 回滚预检和 PostgreSQL 两库恢复脚本。目标机 root/锁/0600 私有配置已准备，非密钥 URL 已填写；2026-10-01 已在 B 主机首次生成全新专属 PostgreSQL/Redis/MinIO/JWT/内部服务凭据，重复运行未轮换，随后 Resend 和从 A 读取的 OpenAI 密钥已安全同步到 B 私有 env；B 决定只走普通邮箱注册／验证／登录，目标机私有 env 已显式关闭邀请码路径；MinIO/Redis 的**正式数据**备份与隔离恢复、离机留存、可执行 B 发布/回滚 runner 与上线验收仍未完成。合成恢复不能当作目标机真实恢复。

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
- B 两份私有 env 已在目标机完成本地一次性专属凭据初始化，权限仍为 0600；
  不复用 A 的 DB/Redis/MinIO/JWT/服务密钥，后续发布只读取它们。
  Resend 与 A 链路当前 OpenAI 密钥已在 B 私有 env 中同步；目标机上的
  SMTP/STARTTLS 登录和 OpenAI `/v1/models` 鉴权通过，但未发送邮件或模型推理。
  B 只走普通邮箱注册／验证／登录。Backend `dev` 提交
  `a9842f9c2bd591ece61c94308751c6dfc3cf7a64` 的 B CI 通过后，
  目标机现有私有 env 已设置 `AUTH_INVITE_LOGIN_ENABLED=false` 和显式空
  `AUTH_INVITE_CODES=`，未轮换其余凭据。Backend/Agent 静态预检、两服务共享配置
  匹配检查以及 Backend Compose 静态渲染均通过；没有发送邮件或启动服务。
  目标 JSON 与 env 已写入上述两个 B 域名，
  但域名 HTTPS 超时，主机无 :80/:443 listener 和公信证书；目标实例绑定的
  `launch-wizard-25` 安全组也无 TCP 80/443 入站规则，需按变更流程放行并复测。
  **尚未部署** PostgreSQL、Redis、MinIO、Product、Agent 或反向代理。
  历史托管数据确认不迁入。B Docker 新环境守卫通过，但普通 `ubuntu`
  用户无 Docker socket 权限，守卫以 `sudo -n` 执行；发布 runner 的权限模型
  需明确。后续仍要完成 HTTPS/TLS、公有端口与证书、真实备份与隔离恢复
  及离机留存，提供可审核的 B 发布/回滚入口，
  再完成真实邮件、服务和 Agent
  10 并发验收。不得绕过这些门禁。

## B 镜像发布任务（与目标机部署分离）

Backend/Agent 的 B 验证 workflow 在 GitHub `dev` **push 且验证任务成功**后，另起
`b-image` 任务从各自 `deploy/Dockerfile` 构建 `linux/amd64` 镜像，发布到私有
GHCR 的 `b-dev-<完整 commit SHA>` 标签，对最终 digest 做离线镜像核验并记录
不可变 digest。PR／手动 workflow 派发只验证，
不发布镜像。CI 不 SSH 目标机、不启动服务、不切换 `current`；目标机尚未配置私有 GHCR 拉取身份或拉取并核验 digest。镜像发布成功不代表
B 服务已部署或可对外使用。实际部署仍须先验证目标机私有配置、域名/TLS、
PostgreSQL/MinIO/Redis 的正式备份与隔离恢复门禁。

## 2026-10-01 8001/8002 配置与公网入口核验

- Backend/Agent 的 B 专属模板和目标机两份私有 env 已分别切换至
  `127.0.0.1:8001`／`127.0.0.1:8002`；env 保持 0600，未变更密钥。
  本地回归、GitHub B CI、目标机静态预检、Compose quiet 渲染均通过。
- AWS 只读检查确认目标实例绑定的 `launch-wizard-25` 安全组只有 TCP 22
  入站，没有 80/443；目标机临时监听 0.0.0.0:80/:443 时，外部连接仍超时，
  探针随后清除。NACL 的只读查询因 IAM 拒绝，不能宣称已核验。
- B 主机已安装 Nginx/Certbot，但安装包默认站点启动后已立即停用；没有
  公信证书或已启用的 B 站点。先经审批开放 80/443 并复测，才能签发证书、
  启用 HTTPS 反向代理。GHCR 私有镜像在目标机读取被拒，还需安全配置只读
  拉取身份；只读准入入口不会启动容器，首次发布入口也未在目标机执行。真实数据备份、
  隔离恢复、更新/回滚与服务验收仍是门禁，**不得宣称后端已上线**。

## 2026-10-02 B 构建与发布入口校正（代码就绪，目标机待验收）

- Backend/Agent 的 `dev` 镜像作业现在先发布 `linux/amd64`，再对**所发布的 digest** 检查用户、来源标签、模块与 Alembic head；CI 仍不登录目标机。
- 两服务 B Compose 子进程使用最小白名单环境，防止操作者 shell 的 A 配置覆盖 B 私有 env；B 目标机变更脚本还拒绝继承远端 Docker context/host，强制本地 Unix socket。B 的 PostgreSQL/Redis 基础镜像与隔离恢复演练固定相同 digest；B 专用 MinIO Dockerfile 固定构建基础镜像、目标为 amd64，A 的 MinIO 构建文件不变。
- Backend 提供 `scripts/b_first_release.py`：先以只读 `--preflight` 检查准入；只在显式 `--apply` 且首次空白 B 环境下运行，并以独立总锁串行化各阶段，要求可信公网证书及目标机镜像身份，通过单机基础服务启动、双库迁移、三类**真实数据**备份与隔离恢复后按 Product → Agent 顺序激活并验证公网 HTTPS。途中失败保留现场，不能自动回滚/重试；外部邮件与模型服务的 E2E 仍单独验收。
- 这是代码与本地合成验证，**本版远程 CI、GHCR 最终 digest 和美东目标机尚未验收**。应在提交并推送相关服务仓库后跑远程 CI，审查私有 GHCR 只读拉取和目标机镜像导入/真实恢复，然后才考虑执行首次发布。现有业务数据的版本更新、回滚和 10-run 压测仍是未完成项。此前按 2026-10-01 记录的端口、证书和容器状态为历史观察，不能当作当前事实。
