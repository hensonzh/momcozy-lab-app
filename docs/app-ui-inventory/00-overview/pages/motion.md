# 动作评估

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`motion`
- 范围：unreachable
- 入口：Agent 动作卡当前目的路由未注册
- 路由：Navigator／条件入口，见来源
- 实现：[motion_assessment_page.dart](../../../../lib/features/motion_assessment/presentation/motion_assessment_page.dart)
- 当前结论：无正常入口已单列；不制造可达截图。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 预览
- 评估
- 结果

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 预览 | [motion-guide](../../09-motion/motion-guide/README.md) | NO_NORMAL_USER_ENTRY: code documented in ENTRY-STATUS.md; not a required reachable capture |
| 评估 | 无正常入口；见边界说明 | NO_NORMAL_USER_ENTRY: code documented in ENTRY-STATUS.md; not a required reachable capture |
| 结果 | [motion-failure](../../09-motion/motion-failure/README.md) | NO_NORMAL_USER_ENTRY: code documented in ENTRY-STATUS.md; not a required reachable capture |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../09-motion/motion-guide/default.png) · [入口及前驱](../../09-motion/motion-guide/README.md) | 1 | motion responsive failure retry and exit 390.0 / 1.0 |
| [图](../../09-motion/motion-failure/default.png) · [入口及前驱](../../09-motion/motion-failure/README.md) | 1 | motion responsive failure retry and exit 390.0 / 1.0 |

## 实际操作链与状态依据

[ENTRY-STATUS.md](../ENTRY-STATUS.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)
