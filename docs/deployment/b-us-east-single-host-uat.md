# B 发布链路：美东单机自托管 Compose 策略

决策日期：2026-09-30。此文替代 [旧版双链路设计稿](dual-staging-release-lanes.md)
中关于 B 使用 Kubernetes、托管 RDS/Redis/S3 的部署方案。**这是部署策略与
切换计划，不代表 B 已经上线**；Backend、Agent 的 B 发布 CLI 仍保持拒绝。
A 链路保持原样，App 的 B 分发/商店策略不因服务端改用单机而改变。

## 边界与拓扑

```text
GitHub dev -> 独立 B 构建/发布流水线（尚未接通）-> 美东独立服务器
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
   **B Compose 模板、只读私有 env 预检及 面向 GitHub `dev` 的 B 专属验证 workflow 已在本地准备（尚未推送，未生效），但发布流水线尚未接通**，不得拿 A 的部署脚本
   修改几个 URL 直接使用。
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
仅作历史记录，**不得继续作为当前申请或发布清单**。B 专属 CI 在提交并推送后只做合成数据的 PostgreSQL/Redis 隔离测试、Compose 渲染与本地镜像构建；不推镜像、不连接 UAT、不执行发布。B 独立发布 CLI/备份恢复与真实验收仍是后续实施，不在本轮假装完成。
