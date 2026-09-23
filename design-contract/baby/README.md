# Baby 模块 Figma → Flutter 设计契约

`contract.json` 是 Baby 模块的实现与验收入口。它冻结了 Figma 文件 `ePIoJkiMiXiug9ibpcgRbl` 在 2026-09-21 校准的 32 个状态、组件映射、交互刷新规则和设计 token。

- 32 个状态现在都有同尺寸 Figma 参考图；新增的 11 个首页/生长状态已经完成 Flutter 同尺寸截图和对照，仍保留无资料首页导航图片首帧与长名称截断夹具两项待核验。
- `comparisons/actual-home-states/` 保存本轮 11 个首页/生长状态的 Flutter 实际截图，`comparisons/home-state-captures.json` 保存逐状态对照记录。
- `raw/` 保存本次导出的 manifest、资源索引和比较索引。
- `assets` 使用 App 内的本地资源路径 `app/assets/images/baby_figma/`，运行时不依赖 Figma 临时 URL。
- `evidence.json` 记录当前测试、设备复核和本轮校准差异；它不是设计输入，修改视觉后必须同步更新。

校验契约：

```bash
python3 /Users/lute/.codex/skills/figma-to-app/scripts/validate_contract.py \
  app/design-contract/baby/contract.json
```

Baby UI 修改必须先更新契约中的状态或 override，再运行同尺寸截图和 Flutter 交互测试。参考图和 App 实际截图必须按状态一一比对，不要把 App golden 当作 Figma 参考图。

本轮截图夹具：

```bash
flutter test test/modules/baby/baby_home_state_capture_test.dart
```
