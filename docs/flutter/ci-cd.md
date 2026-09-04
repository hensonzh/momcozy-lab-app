# Flutter CI/CD 与 Test 发布

当前只有 `local`、CI 和 `test` 交付链路，没有 production 发布配置。
`unified` 是 Android 安装/分发 flavor，不是新的服务器环境：它使用独立的
`com.momcozymai.app.flutterpoc.unified` applicationId，但编译时固定注入
`MOMCOZY_ENV=test`，连接现有 Product Backend 与 Agent Runtime test SNI
入口。

## 持续集成

`.github/workflows/app-ci.yml` 在 pull request、`main` 和
`integration/**` push 上运行，并固定 Flutter 3.44.4、Java 17、Node 20 和
Python 3.13。门禁包括：

1. 构建脚本与双服务 OpenAPI 快照契约测试；
2. Android packaging 与安全隐私静态检查；
3. `dart format`、`flutter analyze --no-pub`，并在 Linux 跑完整非视觉测试；
4. 在独立的 macOS 15 job 上跑标记为 `golden` 的视觉基线测试；
5. 使用两个 test HTTPS 地址构建 `unified` debug smoke APK；
6. 将该 APK 保存为短期 workflow artifact。

golden 基线以 macOS + 固定 Flutter 3.44.4 为规范渲染环境。Hosted macOS 的芯片和
系统栅格器仍可能与基线生成机产生少量抗锯齿差异，因此该 job 通过 Flutter 官方
`GoldenFileComparator` 扩展接受最多 1.1% 的像素差异；本地未设置该容差，仍执行严格
逐像素比较。发布 workflow 复用已由主干 CI 验证的视觉结果，因此其 Linux release gate
运行 `flutter test --no-pub --exclude-tags=golden`。CI 不签正式包、不写 GitHub
Releases、不更新 Pages，也不部署后端。

## 受保护的 Test 发布

`.github/workflows/app-test-release.yml` 只能手动触发，使用 GitHub
`test` environment 记录部署、使用串行 concurrency，且只接受从 `main` 分支发起。
当前三个仓库均为 private，现有 GitHub 套餐不支持 private repository required
reviewers，因此不能把空的 environment 当成审批门禁。每个仓库需要先创建一个固定的
审批 issue，并设置两个 repository variables：

- `TEST_APPROVAL_ISSUE`：审批 issue 编号；
- `TEST_APPROVERS`：逗号分隔的 GitHub operator login 白名单。

独立 approval job 不读取发布 secret，并等待白名单操作者在该 issue 下发送 job summary
展示的完整 `/approve-test ...` 命令。发起人可以完成这次独立的二次确认，这与未启用
prevent-self-review 的 GitHub required reviewer 语义一致。命令绑定 repository、run ID、
attempt 和触发 SHA；缺少变量或 30 分钟内未批准都会 fail closed。
发布 job 始终 checkout 审批时的 `github.sha`，不会在等待期间漂移到更新的 `main`。
迁移后，三个远程仓库都必须使用审批 issue `#1`、`TEST_APPROVAL_ISSUE=1` 和
`TEST_APPROVERS=hensonzh`；`test` environment 仅记录部署，不承担审批语义。在代码
推送且 `TEST_*` secrets 完成配置前，不得删除旧 environment 或触发新版工作流。

配置以下 test environment secret；若当前套餐不支持 private environment secret，
则配置为 repository secret：

- `FLUTTER_RELEASE_KEYSTORE_BASE64`
- `FLUTTER_RELEASE_STORE_PASSWORD`
- `FLUTTER_RELEASE_KEY_ALIAS`
- `FLUTTER_RELEASE_KEY_PASSWORD`
- `TEST_SMOKE_INVITE_CODE`，仅绑定隔离的 smoke 账号
- `TEST_SMOKE_DEVICE_ID`
- `RELEASES_GH_TOKEN`，仅授予 `hensonzh/momcozy-lab-releases` 所需的
  Releases/Contents 权限
- `TEST_SSH_HOST`、`TEST_SSH_PORT`、`TEST_SSH_USER`、
  `TEST_SSH_PRIVATE_KEY`、`TEST_SSH_KNOWN_HOSTS`，读取当前两份
  `/opt/momcozy-lab/current/*/release-manifest.json` 并获取共享 test 发布锁

手动输入必须来自已经部署的两份服务 release manifest：

- Product Backend full commit、image digest、OpenAPI SHA-256；
- Agent Runtime full commit、image digest、OpenAPI SHA-256。

工作流会先校验 full commit/digest 格式，通过已验证 host key 的 SSH 读取当前部署
manifest 并与全部输入逐项比对，确认 OpenAPI hash 与 App 固定快照一致，再通过内置
test CA 下载两个公网 `/openapi.json` 并做 JSON 语义等价校验。耗时依赖安装完成后，
工作流才用隔离账号即时 invite-login，并立刻执行 live smoke，不保存会在 15 分钟后
过期的 access token。工作流会查询该账号的 infant；首次运行时通过固定幂等键创建一条
专用 smoke infant，后续直接复用其 ID，不维护容易与账号所有权漂移的 Baby ID secret。
之后强制正式签名，记录签名证书 SHA-256，并同时启用 Product
读写/对象存储 smoke 与 Agent SSE smoke；Agent 必须出现非空 assistant 响应并以
`run.completed` 结束，任一失败终态都阻止发布。

发布已构建 APK 前，工作流在宿主机获取与两个服务发布相同的 `flock`，重新读取两份
current manifest，并验证 Agent 记录的 Product 依赖恰好等于当前 Product 身份。这样
三个仓库各自的 GitHub concurrency 不能造成跨仓库竞态。Flutter setup 的外部 Action
固定到完整 commit，由依赖更新流程显式升级。宿主机锁由 SSH 会话绑定的 holder 持有：
远端命令在 SSH stdin EOF 时退出并释放 `flock`，工作流用 runner 临时目录中的 0600 FIFO
保持 stdin；`EXIT` cleanup 先停止 FIFO writer，再回收 SSH。发布脚本结束或 runner 中断
都不会留下脱离会话的 holder，也不使用会提前到期的固定租期。

release gate 只构建一次 `app-unified-release.apk`。发布步骤通过
`MOMCOZY_APK_INPUT` 复用这同一文件，生成 SHA-256、下载页和包含 App commit、
两份服务 commit/image digest/OpenAPI hash 的 manifest。GitHub Release tag 和
APK 名分别为：

```text
unified-android-v<version>-<build>
momcozy-unified-android-test-<version>-<build>.apk
```

每个 tag 同时保存 APK、checksum 和一份不含生成时间的 provenance JSON；后者固定
App commit、服务 commit/digest/OpenAPI hash、签名证书和 APK hash。已存在 tag 时，
脚本只接受三份文件逐字相同；任一内容不同都会失败并要求增加 build number，绝不
覆盖资产。Pages 只写 `/unified/` 命名空间，不改动仓库根页面或其他项目目录。
`momcozy-lab-releases` 的 Pages 必须由管理员预先配置为从 `main` 分支根目录发布；
发布脚本不会调用 Pages/Administration API。脚本只在临时 clone 内配置
`gh auth git-credential`，让原生 `git push` 使用 `RELEASES_GH_TOKEN`，不修改 runner
之外的全局 git 配置。

## 版本、回滚与边界

- 每次对外内测发布先递增 `pubspec.yaml` build number。
- APK、SHA-256、immutable provenance、下载页 manifest 和 workflow artifact 都来自
  同一个已签名 APK。
- App 回滚是重新分发一个更高 build number、但指向兼容服务合同的新包；不要覆盖
  已发布 tag/asset。
- 后端回滚不会自动触发 App 回滚。发布 App 前必须重新执行双服务 live join gate。
- keystore 只物化在 runner 临时目录，任务结束时删除；密码和 token 不写入产物。
- production flavor 仍仅用于 production-shaped 本地验证，当前工作流拒绝发布它。
