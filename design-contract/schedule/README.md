# Schedule Figma → Flutter 设计契约

`contract.json` 是 Schedule 当前实现与验收入口，基准来自 Figma Schedule Page `567:1133`，最后一次完整校准记录为 2026-09-21。

- `references/`：同尺寸 Figma 参考图。
- `actual/`：Flutter 实际渲染图。
- `comparisons/`：并排、叠图、差异图及参数。
- `assets/`：指向 App 运行时资源的仓库内链接。
- `evidence-assets/`：校准说明、日志与 Android 模拟器证据。
- `raw/`：Figma 来源说明与资源映射。
- `evidence.json`：视觉、交互和设备验证状态。

当前仍有刷新失败、日期选择器、时间选择器和放弃草稿四项缺少对应 Figma 参考图；它们只能视为交互已验证，不能宣称视觉验收完成。

修改 `lib/modules/schedule/` 后，应同步更新契约和证据，并运行结构校验及 Schedule 定向测试。
