# 用户 App 页面与状态地图

用户 App UI / UX 盘点已完成。28 个常规页面及配置／兜底／无入口页面分列，213 条页面状态、35 类浮层的 166 条状态均有对应记录。[交付验收与运行边界](00-overview/AUDIT.md)。

- [独立页面总清单](00-overview/PAGE-CATALOG.md)：27 个默认路由页面、1 个视频全屏页面；配置页面、无效入口和不可达代码单列。
- [弹窗与浮层清单](00-overview/OVERLAY-CATALOG.md)：按宿主页面列出 35 类交互层及其状态。
- [页面与操作链对应](00-overview/PAGE-INTERACTION-MAP.md) · [浮层逐状态截图](00-overview/OVERLAY-STATE-MAP.md)。
- [明确补图与核对队列](00-overview/VISUAL-GAPS.md)：12 项具名工作均已关闭，保留处理依据。
- [补图判定与复用清单](00-overview/CAPTURE-DECISIONS.md)：保留既有补图判定；最终处置以交付验收为准。
- [归并后的页面证据](00-overview/EVIDENCE-GROUPS.md)：同页像素相同的完整图共享代表证据，保留每个入口和操作链。
- [全部原始条目](EVIDENCE-INDEX.md)：历史批次、尺寸/字号、原始窗口和逐状态 README，未删除任何图。

原要求仍是完整 Page × State × Interaction 盘点，不能用页面计数或测试通过替代完成证明。[原始要求](00-overview/REQUEST.md) · [完成审计](00-overview/AUDIT.md) · [原生截图](native/) · [机器清单](00-overview/page-catalog.json)。

更新原始证据索引后，使用安装了 Pillow 的 Python 运行 `scripts/catalog-app-ui-inventory.py`，重新归并；未补图时无需重新运行 Flutter 采集。
