# MomCozy App

MomCozyApp 当前以 Flutter 原生实现为主线，目录边界如下：

```text
flutter_app/   Flutter 移动原生实现
legacy_web/    旧版 React/Vite/Capacitor 实现归档，不进入 Flutter 主线脚本
docs/          Flutter、后端合同和设备协议文档
scripts/       Flutter toolchain、release gate、smoke 和合同校验脚本
test/          根级测试 fixtures；Flutter 测试在 flutter_app/test/
```

根目录 `package.json` 只保留 Flutter 主线相关脚本。旧 Web 的 React/Vite/Capacitor 依赖和 lockfile 保留在 `legacy_web/` 内，如需查看或手动运行旧版实现，请直接进入该目录。

## 新版 Flutter

首次检查本地 Flutter 工具链：

```bash
npm run flutter:check
```

启动 Flutter App：

```bash
npm run flutter:dev
```

非真机构建和测试 gate：

```bash
npm run flutter:release-gate
```

## 文档目录

文档统一存放在 `docs/` 下，目录说明见 `docs/README.md`。
