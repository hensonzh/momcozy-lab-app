# 用户 App 公共设计系统验收

范围为 `common/theme` 所代表的全局设计系统及其公共承载组件。依据当前生活陪伴型定稿、styles.css、me-agent.css、me-diary.css、baby.css 和用户确认的登录稿；具体页面仍以 page-map 的独立验收为准，业务缺口不因主题完成而关闭。

| 要求 | 当前实现与检查 | 证据 |
| --- | --- | --- |
| Color | MomCozyColors 提供奶油底、暖白表面、可可正文、玫瑰品牌、绿/蓝状态与危险色；Theme ColorScheme、分隔线及反馈复用语义值 | `test/app/momcozy_design_system_test.dart`、`test/app/me_theme_test.dart`；现有各模块原稿/原生截图 |
| Typography | 用户默认标题 Manrope 28/1.1、21/1.2、18/1.2；正文 DM Sans 和中文回退；公共段落 1.55，Cozymate 16/1.65、Markdown 标题17/1.5；登录/首次使用标题沿用已批准衬线稿 | `evidence/typography`、`evidence/agent-markdown`、`evidence/onboarding-reading`，含实际 RenderParagraph 与 Android 1x/2x |
| Spacing | 公共 8/12/16/24 节奏；妈妈主页实际使用 MomCozyInsets.home（27/8/32）；服务与沉浸页用各自稿件的外边距 | mother_home_page.dart、momcozy_design_system.dart；页面映射及逐页截图 |
| Radius | 18 主卡、12 控件、全圆胶囊；导航14、日记/底部弹窗等按局部稿件覆盖 | MomCozyRadii、MomCozySurface、ProductFlowDialog、WarmEditorHeader；me_components 与 input_confirmation |
| Shadow | 普通卡片采用细暖灰边界、平面 Material；局部卡片和弹窗按稿件加入弱阴影，底部导航集中使用 MomCozyShadows.navigation | momcozy_theme.dart、momcozy_design_system.dart；me_components 与导航截图 |
| Icon | 底部导航使用设计 SVG；MomCozyLineIcon 集中承载 UI.tsx / MeOverview 线图；原生媒体控制保留可理解的语义图标及标签 | assets/images/nav_*.svg、mom_bottom_navigation.dart、momcozy_line_icon.dart；导航、媒体及表单页面截图 |
| Button | 可可色默认主按钮、描边/文字次操作，触控至少44；登录/品牌选择按确认稿使用玫瑰色；忙碌、禁用、错误和重试保留原业务能力 | Theme 与 ServiceFlowTheme；me_theme、me_components、input_confirmation，首次使用及咨询原生验证 |
| Card | MomCozySurface / MomCozyDecorations、共享反馈、共享 Agent 卡片承担公共边界；日记、知识及咨询内容按局部设计呈现 | me_components、product_feedback、knowledge_article_design；`evidence/form-cleanup` 与页面映射 |
| Input | 通用输入和选项集中复用，暖白底、边框/形态双重选中反馈；大字号及键盘下支持滚动、保留草稿与恢复 | choice_field、date_time_picker、input_confirmation 与 me_theme 的实际交互检查 |
| Navigation / Bottom Tab | 五个一级入口 Me/Baby/Cozymate/Schedule/More；子页面保留返回路径；底部导航处理安全区和放大字号 | mom_navigation、momcozy_route_shell_contract；本轮及既有 Android 页面截图 |
| 动态效果与范围隔离 | 减少动态效果覆盖路由、弹层、选择器、滚动和装饰；工作台由 isWorkbench 显式保留原排版，不混入用户主题段落扩展 | momcozy_motion、route_motion、me_theme；`evidence/theme-motion` 的原生证据 |

## 局部文字覆盖的结论

紧凑行高并非都属于遗漏的段落。当前隐私授权行的 14/1.4 标题、12/1.5 说明与11/1.45影响提示，逐项对应 styles.css 2482–2484；服务次数、倒计时、日程元信息、候选项标签属于短标签或控件。登录 Libre Caslon 与等宽代码分别有明确的场景用途，不用统一段落样式覆盖。

实际发现的旧段落覆盖已修正：公共反馈、通知/账号说明、Agent Markdown，以及首次使用的照片隐私、阶段、等待、启用与步骤用途说明。此结论与前面“仍待逐项核对”的历史记录相比，以本次复核及相应修正证据为准。

## 验证与保留项

当前公共主题/导航/路由/共享组件 111 项检查通过，记录为 `evidence/onboarding-reading/theme-regression.log`；首次使用相关94项、Agent/媒体相关544项分别保留在对应证据目录。本轮 Android 8 张首次使用截图、前轮4张 Markdown截图以及现有主题/输入/动态效果原生验证共同覆盖公共规范使用，不以构建成功替代视觉验证。

`common/theme` 可以标为 Completed。隐私授权与恢复授权入口、咨询结束后 Cozymate 上下文、自主管理保存和转介提交仍分别保留 Need Review；这些未实现的业务契约不由公共主题验收替代。
