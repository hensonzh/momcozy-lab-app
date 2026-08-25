# Android APK GitHub Releases 分发

Flutter 内测包通过公开仓库 `hensonzh/momcozy-lab-releases` 分发：

- GitHub Release 保存 APK 和 SHA256 文件，APK 不进入 Git 历史。
- GitHub Pages 保存极简下载页、二维码和 manifest。
- 二维码和点击下载均直接指向 GitHub Release 的可信 HTTPS 地址。
- MomCozyApp 源码仍保存在私有仓库，不会复制到公开发布仓库。

## 一键构建与发布

先安装并登录 GitHub CLI：

```bash
gh auth login
```

然后执行：

```bash
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443 \
./scripts/build-flutter-app.sh
```

上面的两个地址是当前 staging 已配置的固定 SNI 服务地址。

默认配置：

```text
Download:  https://hensonzh.github.io/momcozy-lab-releases
Releases:  hensonzh/momcozy-lab-releases
Variant:   staging release
```

`staging` 和 `production` 没有 API 默认值：必须显式提供两个非空、非
loopback 的 HTTPS 地址，即 Product Backend `MOMCOZY_API_BASE_URL` 与 Agent
Runtime `MOMCOZY_AGENT_API_BASE_URL`。两者必须分别配置。
`local` 构建缺省使用 Product Backend `http://127.0.0.1:8769` 和 Agent Runtime
`http://127.0.0.1:8010`。

只校验配置、不安装依赖或启动构建：

```bash
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443 \
./scripts/build-flutter-app.sh --check-config
```

脚本会依次：

1. 构建 Flutter APK。
2. 生成极简下载页、manifest 和带 “Momcozy Lab” 文本的二维码。
3. 创建或更新 `android-v<version>-<build>` GitHub Release。
4. 将 APK 和 SHA256 文件上传为 Release 资产。
5. 更新公开仓库根目录中的 GitHub Pages 文件。
6. 输出 App 发布链接和邀请码管理后台链接。

每次发布前必须增加 `pubspec.yaml` 中的构建号，避免覆盖已经分发的版本。当前内测阶段，
`版本号+构建号` 同时也是账号数据重置边界：用户首次启动新构建会退出账号，重新登录后
清空该账号的云端业务数据并统一进入 onboarding；同一构建重复启动不会再次清理。

## 常用参数

以下 staging 示例假定已经导出两个 API 环境变量：

```bash
export MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443
export MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

```bash
# 只生成本地产物，不发布
MOMCOZY_SKIP_UPLOAD=1 ./scripts/build-flutter-app.sh

# 跳过重复的 npm ci
MOMCOZY_SKIP_NPM_CI=1 ./scripts/build-flutter-app.sh

# 使用其他公开发布仓库和 Pages 地址
MOMCOZY_GITHUB_RELEASE_REPO=owner/repository \
MOMCOZY_DOWNLOAD_BASE_URL=https://owner.github.io/repository \
./scripts/build-flutter-app.sh

# 强制要求正式 release signing
MOMCOZY_REQUIRE_RELEASE_SIGNING=1 \
./scripts/build-flutter-app.sh
```

底层下载页生成命令仍可单独执行：

```bash
MOMCOZY_GITHUB_RELEASE_REPO=hensonzh/momcozy-lab-releases \
MOMCOZY_DOWNLOAD_BASE_URL=https://hensonzh.github.io/momcozy-lab-releases \
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443 \
make flutter-apk-download-site
```

`MOMCOZY_EXTRA_DART_DEFINES` 只用于其他开关；其中出现
`MOMCOZY_API_BASE_URL` 或 `MOMCOZY_AGENT_API_BASE_URL` 会直接失败，不能覆盖
一等配置。

本地产物结构：

```text
dist/android-apk/
  index.html
  manifest.json
  assets/momcozy-lab-download-qr.svg
  releases/momcozy-android-staging-1.0.0-8.apk
  releases/momcozy-android-staging-1.0.0-8.apk.sha256
```

## 验证

发布后确认：

- GitHub Pages 页面只显示简短说明、版本号和二维码。
- `manifest.json` 中的 `apkUrl` 指向当前 GitHub Release 资产。
- 点击或扫描二维码会跳转到 `github.com/.../releases/download/...`。
- APK 下载支持中断恢复，SHA256 与本地产物一致。
- Android 安装时允许来自当前浏览器的未知来源安装。

## 注意事项

- 公开仓库意味着任何获得链接的人都可以下载 APK，包内不得包含密钥或测试账号。
- `dist/` 已被 `.gitignore` 忽略，不会提交到 MomCozyApp 仓库。
- 未配置正式 release signing 时，release APK 只适合内部测试。
- 如果用户已安装签名不同的旧包，需要先卸载旧包。
