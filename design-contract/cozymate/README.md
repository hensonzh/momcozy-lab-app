# Cozymate Figma → Flutter 设计契约

`contract.json` 是 Cozymate 当前实现与验收入口。当前基线包含文字对话、流式状态、断线恢复、当前会话恢复、历史向上分页和附件流程；新建会话、会话列表/切换、语音、表单、操作确认和结构化结果卡片不在一期范围。

- `references/`：同尺寸 Figma 参考图。
- `actual/`：Flutter 实际渲染图。
- `comparisons/`：并排、叠图、差异图及参数。
- `evidence-assets/attachment-menu/`：附件菜单的组件级和设备级校准证据。
- `raw/`：Figma 原始上下文。
- `evidence.json`：截至 2026-09-23 的验证结果、已知限制和恢复行为。

修改 `lib/features/agent_hub/` 后，应同步检查契约状态及证据。测试生成的临时截图写入 `build/design-evidence/cozymate/`，不得重新依赖仓库外的 `../design-assets/`。
