# MomCozy App

MomCozyApp 现在同时保留 Flutter 原生重构实现和旧 Web/Capacitor 实现，目录边界如下：

```text
flutter_app/   新版 Flutter 移动原生实现
legacy_web/    旧版 React/Vite/Capacitor 实现，作为 UI 对齐基线和回滚来源
docs/          迁移、Flutter、API、旧 Web、UI parity 和后端合同文档
scripts/       Flutter 迁移 gate、UI parity、回滚包和审计脚本
test/          UI parity 截图与报告
```

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

## 旧版 Web

旧版实现已归档到 `legacy_web/`，但根目录仍保留常用 npm 命令：

```bash
npm install
npm run dev
npm run build
npm test
```

其中 `npm run dev/build/test` 会使用 `legacy_web/vite.config.ts` 和 `legacy_web/vitest.config.ts`。

如需同步旧 Capacitor Android 工程：

```bash
npm run build
cd legacy_web
npx cap sync android
```

## UI 对齐

旧 Web 截图基线：

```bash
npm run ui:legacy-reference
```

Flutter 与旧 Web 的页面级视觉 diff：

```bash
npm run ui:parity-report
```

旧 Web 的 UI/UX 黄金标准见 `docs/ui-parity/legacy-web-ui-ux-golden-standard.md`；组件级重绘计划见 `docs/ui-parity/flutter-ui-component-parity-plan.md`。

## 文档目录

文档统一存放在 `docs/` 下，目录说明见 `docs/README.md`。
