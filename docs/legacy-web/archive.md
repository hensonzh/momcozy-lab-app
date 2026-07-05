# 旧 Web 实现归档说明

## 目录边界

旧版 React/Vite/Capacitor 实现已经统一归档到：

```text
legacy_web/
```

主要内容：

| 目录或文件 | 用途 |
|---|---|
| `legacy_web/src/` | 旧 Web React 页面、组件、hooks、API 封装和测试。 |
| `legacy_web/android/` | 旧 Capacitor Android 工程和原生插件。 |
| `legacy_web/public/` | 旧 Web 静态资源。 |
| `legacy_web/patches/` | 旧 Capacitor 依赖补丁。 |
| `legacy_web/vite.config.ts` | 旧 Web Vite 开发和构建配置。 |
| `legacy_web/vitest.config.ts` | 旧 Web Vitest 配置。 |
| `legacy_web/tailwind.config.ts` | 旧 Web Tailwind 配置。 |

新版 Flutter 实现在：

```text
flutter_app/
```

根目录 `package.json` 仍保留 `npm run dev/build/test`，这些命令现在显式指向 `legacy_web/`，用于旧 Web 调试、UI parity 基线和回滚包生成。

## Flutter 对旧 Web 的依赖结论

当前 Flutter App 的运行时和构建路径不依赖 `legacy_web/` 里的源码、组件或资源。

仍保留的关联是迁移和验证用途：

| 关联 | 是否运行时依赖 | 说明 |
|---|---:|---|
| UI parity 截图 | 否 | `test/screenshots/legacy_web/` 是旧 Web 截图基线，用来比较 Flutter 页面视觉差异。 |
| 迁移文档源码定位 | 否 | 文档中的 `src/...` 旧引用现在等价于 `legacy_web/src/...`。 |
| 回滚包 | 否 | `npm run build` 生成 `legacy_web/dist/`，用于当前 Capacitor/Web rollback source。 |
| 安全/打包检查 | 否 | 脚本会读取 `legacy_web/android/`，确保旧 Capacitor appId 和安全约束未被 Flutter 迁移破坏。 |
| 存储迁移兼容 | 否 | Flutter 代码处理的是旧 localStorage/Capacitor Preferences 数据 schema，不直接读取旧 Web 文件。 |

因此，`legacy_web/` 可以作为清晰隔离的历史实现和迁移参照保留；Flutter 新实现应继续只从 `flutter_app/` 内部代码、Flutter assets、typed API client 和 platform channel 契约取依赖。
