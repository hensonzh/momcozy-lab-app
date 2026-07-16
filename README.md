# MomCozy App

MomCozyApp 当前仅维护 Flutter 原生实现，目录边界如下：

```text
flutter_app/   Flutter 移动原生实现
docs/          Flutter、后端合同和设备协议文档
scripts/       Flutter toolchain、release gate、smoke 和合同校验脚本
test/          根级测试 fixtures；Flutter 测试在 flutter_app/test/
```

Flutter 工程统一通过 `Makefile` 和 `scripts/` 管理启动、检查、构建和 smoke。

## Flutter App

首次检查本地 Flutter 工具链：

```bash
make flutter-check
```

启动邀请码登录 Flutter App：

```bash
make flutter-invite-dev
```

非真机构建和测试 gate：

```bash
make flutter-release-gate
```

## 文档目录

文档统一存放在 `docs/` 下，目录说明见 `docs/README.md`。
