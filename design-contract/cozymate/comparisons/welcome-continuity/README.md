# 欢迎语衔接修复 · 2026-09-23

首次发送后，已显示的完整欢迎语原文保留为普通助手气泡，随后显示用户消息和实际回复。重试、继续追问和断线恢复不重复插入欢迎语。

App 删除了重新生成简短欢迎语的归档逻辑。Figma 的 streaming、reply、disconnected-empty、disconnected-partial、resumed、terminal-error 六个画板已同步修改，并导出 393×844 的原尺寸 PNG。

验证结果：

- 修复前，已有首次发送失败测试和新增完整欢迎语回归测试均复现了文案被改写的问题。
- 修复后，三个相关测试文件共 96 个测试通过，包含 320/390/430 宽度、1×/2× 字号及 393×844 状态截图；静态检查、设计契约检查通过。
- 截图用例现在等待所有可见图片加载完成，消除了首次截图偶发缺失 Me/Baby 导航图标的问题。更新 36 张发送后状态基线及 1 张受此加载问题影响的首页基线，其余 5 张首页基线保持原样。
- 六个 Figma 画板的完整欢迎文案、消息顺序与布局均已人工检查；流式和完成状态另有同尺寸并排图、叠图与差异图。

范围说明：本次完成欢迎语内容与消息衔接修复。App 与 Figma 整页仍存在背景、头像、字重/行高、按钮等既有差异，因此未标记为像素级视觉验收通过。断线与多轮状态的本地截图包含不同草稿或前序消息，仅作行为证据，不作相同数据的整页比对。本次验证未涉及设备安装或发布。

复现命令（在 app 目录）：

```sh
flutter test --no-pub test/features/agent_hub/agent_welcome_continuity_test.dart test/features/agent_hub/agent_hub_page_test.dart test/features/agent_hub/agent_conversation_design_test.dart
flutter analyze --no-pub lib/features/agent_hub/agent_hub_page.dart test/support/agent_conversation_scenarios.dart test/features/agent_hub/agent_welcome_continuity_test.dart
```

- [完整测试日志](flutter-tests.log)
- [六个 Figma 状态](../../references/welcome-continuity/overview.png)
- [流式状态对照](streaming/side-by-side.png)
- [回复完成状态对照](reply/side-by-side.png)
