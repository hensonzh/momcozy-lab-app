# MomCozyApp 文档目录

本文档目录统一承载迁移、Flutter 工程、旧 Web 归档、API 合同和 UI parity 资料。后续不要再新增根目录 `doc/`。

## 目录约定

| 目录 | 内容 |
| --- | --- |
| `api/` | 旧 Web/Agent/API/BLE 协议资料，作为迁移对照和合同来源。 |
| `backend-contract/` | 生产后端 OpenAPI 快照、Flutter client compatibility 和 smoke flows。 |
| `flutter/` | Flutter 工程化、打包、发布 gate、安全隐私和 staging smoke 文档。 |
| `legacy-web/` | 旧 React/Vite/Capacitor 实现的归档说明。 |
| `migration/` | Flutter 迁移蓝图、测试方案、feature/API/storage/route/native bridge 矩阵。 |
| `ui-parity/` | 旧 Web UI/UX golden 标准、Flutter 视觉评估和组件级 parity 计划。 |

## 常用入口

- 迁移总蓝图：`migration/flutter-migration-blueprint.md`
- App 端测试方案：`migration/flutter-app-test-plan.md`
- Flutter 生产重构计划：`flutter/production-refactor-plan.md`
- 旧 Web 归档说明：`legacy-web/archive.md`
- UI/UX 黄金标准：`ui-parity/legacy-web-ui-ux-golden-standard.md`
- 组件级 parity 计划：`ui-parity/flutter-ui-component-parity-plan.md`
- 后端合同快照：`backend-contract/openapi.generated.json`
