# Momcozy App 设计契约

本目录是 App 设计实现与视觉验收的版本化事实源，由 `app` 仓库负责维护。

当前契约：

- `baby/`：Baby 页面、记录、资料与知识弹窗。
- `cozymate/`：Cozymate 当前会话、恢复、错误状态与附件。
- `schedule/`：Schedule 月/周视图、状态、编辑流程与设备证据。

使用规则：

1. 用户最新确认的产品要求优先于旧截图和历史交接文档。
2. `contract.json` 是实现入口，`evidence.json` 记录验证状态；`raw/` 和 `evidence-assets/` 只保存来源与证据。
3. App 源码、测试和正式文档不得依赖仓库外的 `../design-assets/` 路径。
4. 测试生成的临时截图写入已忽略的 `build/design-evidence/`；需要长期保留时，经复核后再复制进对应契约目录。
5. 修改相关 UI 后，应同步更新契约、证据并运行结构校验及对应 Flutter 测试。

结构校验示例：

```bash
python3 "$CODEX_HOME/skills/figma-to-app/scripts/validate_contract.py" \
  design-contract/cozymate/contract.json
```
