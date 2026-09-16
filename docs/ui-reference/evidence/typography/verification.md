# 标题字体与覆盖关系复核

## 设计证据

重新阅读生活陪伴型 Design System、styles.css 的 h1/h2/h3 与 .section-title h2，以及登录确认稿、me-agent.css 的局部字体规则。`design-computed.json` 使用当前设计工程的实际样式，在 320/390/430 浏览器视口测量，包含独立基础样式探针和页面现有标题；探针不是新增设计稿。

| 角色 | 当前设计实测 | 用户 App 承载 |
| --- | --- | --- |
| 页面标题 | Manrope 700，28/30.8，字距 -1.12 | headlineLarge / headlineMedium |
| 普通二级标题 | Manrope 700，21/25.2，字距 -.525 | headlineSmall；紧凑 AppBar / 通用 Dialog 标题 |
| 模块标题 | .section-title h2 为 18，继承 1.2 行高与 -.025em 字距 | titleLarge 为 18/21.6、字距 -.45 |
| 控件标签/选中值 | 正文字体；不能因为 Material 的样式名含 title 就改为标题 | titleMedium / titleSmall 保留 DMSans；DropdownButton 默认使用 titleMedium |

通用主题过去将这些标题统一设为 DMSans，26/22/19 与 1.43 行高。现在在主题最终合并后按用户 App 标题角色覆盖，避免全局 `.apply(fontFamily: ...)` 再次抹去 Manrope。没有批量修改页面的局部 CSS 对应样式。

## 已核对的覆盖关系

- 登录与首次使用仍由 `authLoginTheme`、`AuthLoginHeader` 保持 DMSans / Libre Caslon 的确认稿；登录提交按钮明确保留原有文字度量，不能被标题主题改变高度。
- 首页问候使用专门的 `homeGreeting`（Manrope 26、1.1），后续 me-agent.css 的局部规则优先，未改成通用 28。
- `ServiceFlowTheme` 调整表单和按钮，不覆盖正文 TextTheme；日记的局部 Theme 调整输入、展开项和暖色表面。图表 DefaultTextStyle 只覆盖颜色。主题合并仍保留这些局部规则。
- 工作台调用 `momCozyTheme(isWorkbench: true)` 保留原有 26/22/19 和 DMSans；其直接引用的旧排版 token 未改动。这里只显式隔离共用主题入口，未重构工作台页面。
- `MomCozyTypography.lineHeight` 及局部正文仍有待逐项审计；尤其正文 1.55–1.7、局部中文系统字体与控件继承关系，本轮不宣称全部完成。

## 验证与差异判断

- `before.txt` 复现旧标题数值不符合设计；`component.txt` 从最终回归日志摘录用户主题、工作台保留值与三宽大字号键盘操作，完整结果见 `regression.txt`。
- 逐项查看了共享组件、账号/登录、首次使用确认、宝宝资料/校验、咨询结束原因、首页下半屏、媒体长标题等更新前后图。变化集中在标题字形、行高和随标题高度产生的内容位移。图片预览的像素差较大来自顶部高度变化后整张图片移动，图像内容与缩放方式未变。
- 新增 `typography-*.png` 三宽 × 1x/2x，显示真实 Flutter 标题、输入与中文确认弹窗；测试编辑草稿、打开确认并系统返回，检查草稿保留。
- `regression.txt`：1,313 项回归通过，包含更新后的截图匹配与原有交互测试，未使用更新金图模式。
- `native.txt`：Android 1x/2x 的标题、表单与确认弹窗实际运行通过，保存六张截图；已检查文字和按钮完整可读。测试使用局部草稿，不访问业务保存 API。
- `analyze.txt`：主题实现、认证文字样式和相关测试静态检查无问题。
- `workbench.txt`：33 项通过，验证独立工作台文书、列表、报告和路由保持原样，也覆盖测试目录中已有的用户咨询总结页。仅更新用户总结的三个标题基线，工作台金图未重新生成。
- `build.txt`、`install.txt`：普通 local APK 构建和覆盖安装成功。`native-account.png` 为真实已登录本地账号页面，确认标题与账号内容完整显示；没有触发账号绑定、退出或删除操作。测试页面已替换为正常 App。
- 已恢复 Mia 首页，见 `native-restored-home.png` 及对应 XML。
- 宝宝保存测试原先在滚动未完成时点击卡片中心。新增等待布局和可点击断言，随后校验、保存、撤销与结果不确定流程通过，见 `baby-scroll.txt`；未修改对应业务行为。

公共 Theme 继续保持 Need Review，标题通过不代表正文行高和所有局部覆盖关系已验收。
