# 全局主题复核：减少动态效果（进行中）

## 依据与当前结论

已重新阅读原设计工程生活陪伴型 Design System，尤其“减少动态效果设置下不执行非必要动画”的验收条件。`common/theme` 的主参考已由旧 `styles.css :root` 改为该定稿；模块的后续 CSS 仍覆盖局部视觉规则。此处仅记录本轮已验证部分，公共 Theme 仍为 Need Review。

## 本轮修复

- Agent 头像的脉冲和装饰视频已有 `disableAnimations` / `TickerMode` 支持；实际遗漏为回复边框、运行状态文字、思考文字三处持续动画。
- 这三处现在在减少动态效果开启、或页面 TickerMode 停用时停止并复位；恢复设置或页面时恢复动画。仍显示状态内容和静态边框，不更改请求、回复、取消或音频状态。
- 状态文字移除单行省略，允许按可用宽度完整换行；保留设计状态文字的字号和色彩。原稿 `.agent-run-status` 没有强制单行省略要求。
- 状态的父级无障碍说明与子 Text 曾造成同一文案重复播报；现以单一语义标签呈现。

## 证据

- `before.txt`：在减少动态效果开启后，回复边框与两类扫光仍持续调度帧，三个测试均无法稳定结束。
- `text-before.txt`：大字号长状态 `didExceedMaxLines` 为 true。
- `semantics-before.txt`：父级标签与子文本重复合并成两遍相同文案。
- `regression.txt`：修复后 156 项 Agent 检查通过；包含减少动态效果开关、TickerMode 进入/离开、状态切换、长文案与单一播报，以及既有取消、重试、流式回复和会话交互。
- `native.txt`：Android 1x/2x 验证通过；减少动态效果下，间隔 500ms 获取的思考状态截图字节完全一致，动画帧调度数为零。恢复设置后文字动画重新运行，再开启减少动态效果后停止。
- 六张 `native-agent-reduced-*.png`：已目视核对静态头像/边框、状态内容及两倍字号长文案换行。组件夹具没有 runner，不发送消息、请求模型或访问麦克风。
- `analyze.txt`：三个变更文件静态检查无问题。
- `build.txt`、`install.txt`：普通 local APK 构建并覆盖安装成功；恢复登录中的 Mia 首页，见 `native-restored-home.png`。没有保留集成测试入口作为本地 App。

## 后续补齐：首次使用与定位

- `onboarding_page.dart` 的两个选中态，以及任务横幅的尺寸/文案切换已响应减少动态效果。
- `agent_conversation_panel.dart` 与视频全屏在减少动态效果下首帧完整显示。
- 日记、Baby 记录/资料/首页、购买与 Agent 的程序定位已统一接入 `MomCozyMotion`；保留定位功能并处理懒加载内容范围更新。
- 308 项回归及 Android 组件/真实视频验证通过，详见 [验证记录](preferences/verification.md)。

## 尚需继续完成的主题审计

- 应用普通路由和 39 处通用弹窗/底部弹层已完成本轮过渡验证，包含普通模式与 iOS 返回手势，见 [路由验证](routes/verification.md)。12 处日期/时间入口后续也已接入共享组件，并修复大字号校验溢出，见 [选择器复核](pickers/verification.md)。
- Typography 中旧通用行高、标题尺度与各页面后续 CSS 的覆盖关系仍需逐项核对，不能用本轮动画测试宣称全局 Theme 已完成。

以上剩余项未被移出范围，也未因既有页面验收而视为自动完成。Agent 的真实成功回复及历史能力限制仍沿用其页面待复核记录。
