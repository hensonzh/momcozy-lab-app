# 当前安装 App 的入口补验

这些截图来自本地已登录 App 的实际触摸操作，作为入口和系统输入层证据。这里只是原生窗口截图；可滚动页面的完整布局另在模块状态目录采集，不将窗口图称为长图。

| 入口与操作 | 当前条件 / 验证边界 | 原生窗口 | UI 树 |
| --- | --- | --- | --- |
| Bottom navigation → Baby | existing baby, records empty | [截图](baby-ready.png) | [XML](baby-ready.xml) |
| Baby → current baby name | one owned profile | [截图](baby-switcher.png) | [XML](baby-switcher.xml) |
| Baby → name → edit current baby | existing profile; no save performed | [截图](baby-profile.png) | [XML](baby-profile.xml) |
| Baby → name → edit current baby → nickname → input toolbar menu → Show on-screen keyboard | Actual floating Android software keyboard; show_ime_with_hard_keyboard remained 0 in this capture; no text edited or saved | [截图](baby-profile-software-keyboard.png) | [XML](baby-profile-software-keyboard.xml) |
| edit current baby → tap nickname field | existing emulator hardware keyboard mode; floating input toolbar | [截图](baby-profile-hardware-input-toolbar.png) | [XML](baby-profile-hardware-input-toolbar.xml) |
| edit current baby → nickname | Only floating input toolbar, despite setting 1; NOT an expanded software keyboard; setting restored to 0 | [截图](baby-profile-input-toolbar-mode1.png) | [XML](baby-profile-input-toolbar-mode1.xml) |
| edit current baby → nickname → input toolbar menu | OS keyboard menu shown; clipboard not opened | [截图](baby-profile-input-menu.png) | [XML](baby-profile-input-menu.xml) |

完整软件键盘通过工具条菜单的 `Show on-screen keyboard` 展开；原先仅显示工具条的图已重新命名，避免把设置值当成视觉证据。所有操作都未编辑或保存宝宝资料，也未读取系统剪贴板。


## 通知系统设置入口补验

从真实 App 更多页进入消息中心、通知设置和 Android 应用通知设置，再返回原 Baby 页。完整六步截图、XML、状态保持断言和边界见 [通知原生入口](notifications/README.md)。首次系统申请已在后续权限链补齐，见下文；真实推送投递不由截图证明。


[日程原生入口](schedule/README.md)：8 张当前 App 日程、选择器和恢复截图，无真实记录写入。


[Cozymate 原生入口](agent/README.md)：20 张当前 App、系统照片/PDF 选择器、首次相机授权及返回状态截图；原草稿、消息与权限保持。


## Cozymate 资料卡连续链

More → Cozymate → 发送问题 → 资料卡 → PDF / 视频 / 图片 / 续购及返回：18 个状态窗口和 7 张纵向长图，均已检查。见 [完整报告](../00-overview/NATIVE-RESOURCE-JOURNEYS.md)、[原生状态清单](resource-manifest.json)。原包与登录会话恢复证据在报告内。


## 首次通知权限与拒绝恢复

后续完成 More → 消息中心 → 设置 → 首次允许 / 拒绝后系统设置恢复，两条链共 23 个原生状态。首次系统申请弹窗已补验，原包与权限恢复已核验。见 [完整报告](../00-overview/NATIVE-NOTIFICATION-PERMISSIONS.md) 与 [状态清单](permission-manifest.json)。真实推送投递仍待验证。


## 咨询前摄像头与麦克风

新增 15 个正常链状态，真实系统拒绝、重试允许、设备检测成功、咨询确认及返回。两张妈妈页长图覆盖完整滚动范围，原 APK、Mia 和权限已恢复。[报告](../00-overview/NATIVE-CONSULTATION-DEVICES.md) · [状态清单](device-manifest.json)。


## Baby 知识来源与外部浏览器

[知识来源原生链](knowledge-source/README.md)：8 张窗口覆盖实际 WHO 页面加载、Chrome 引导关闭、返回文章与恢复 Mia 首页。六类来源宿主错误与长图见 [报告](../00-overview/BABY-KNOWLEDGE-SOURCES.md)。


## Baby 尿布备注输入层

[Android 浮动工具条、菜单、键盘与返回](baby-diaper-input/README.md)：12 张原生窗口，未输入或保存记录，原 Mia 首页已恢复；系统 Back 在此配置下同时关闭空编辑器。


## Baby 发育观察放弃草稿

[Android 选择、放弃确认、实际离开和重新进入](baby-development-discard/README.md)：11 张窗口，确认草稿清除并恢复原 Mia 首页；未点击保存。

[系统窗口总表](../00-overview/NATIVE-WINDOWS-CATALOG.md)：按类别复用既有 Android 窗口，版本和平台边界单列。
