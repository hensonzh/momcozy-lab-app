# Baby 尿布备注：Android 输入层与返回

在原 Mia 会话、Luna 资料和已安装 local App 上，实际点击 Me → Baby → 今日尿湿 → 补充备注 → 输入框 → Gboard 工具条菜单 → Show on-screen keyboard → Android Back → Me。没有输入备注、点击保存、改写宝宝资料或重装 App。

12 张原生窗口均已逐张查看。每张保留 XML、SHA-256、前驱和操作时间，见 [操作记录](actions.jsonl)、[证据校验](evidence.json) 和 [采集步骤](capture_steps.py)。App 内点击对应前一份 UI 树的控件边界；两个 Gboard 点击因 UI 树不暴露输入层，使用已查看截图中的坐标，来源截图与换算依据保留在操作记录中。

| 前驱 | 实际操作 | 窗口 | UI 树 |
| --- | --- | --- | --- |
| 当前 App | 已有 Mia 登录会话 | [original-mom](original-mom.png) | [XML](original-mom.xml) |
| original-mom | 点击 Baby | [baby-entry](baby-entry.png) | [XML](baby-entry.xml) |
| baby-entry | 点击今日尿湿卡片 | [wet-editor](wet-editor.png) | [XML](wet-editor.xml) |
| wet-editor | 展开补充备注 | [note-expanded](note-expanded.png) | [XML](note-expanded.xml) |
| note-expanded | 点击空备注输入框 | [note-input](note-input.png) | [XML](note-input.xml) |
| note-input | 等待后再次观察，同一输入状态 | [note-input-settled](note-input-settled.png) | [XML](note-input-settled.xml) |
| note-input-settled | 继续任务时重新观察，同一输入状态 | [note-input-resumed](note-input-resumed.png) | [XML](note-input-resumed.xml) |
| note-input-resumed | 点击浮动工具条菜单 | [keyboard-menu](keyboard-menu.png) | [XML](keyboard-menu.xml) |
| keyboard-menu | 点击 Show on-screen keyboard | [keyboard-open](keyboard-open.png) | [XML](keyboard-open.xml) |
| keyboard-open | 一次 Android Back | [keyboard-back](keyboard-back.png) | [XML](keyboard-back.xml) |
| keyboard-back | 再次观察 Baby；关闭记录定位失败，未发送点击 | [editor-close](editor-close.png) | [XML](editor-close.xml) |
| editor-close | 点击 Me | [restored-mom](restored-mom.png) | [XML](restored-mom.xml) |

输入框聚焦后先显示左侧 Gboard 浮动工具条。展开菜单再显示浮动字母键盘；键盘位于屏幕左上部，覆盖部分标题，顶端部分按键落在屏幕外，并带有“See more features”提示。备注和保存按钮仍在下面。这里记录当前模拟器的真实位置，不把它当作标准底部停靠键盘。

一次 Android Back 同时关闭输入层与空编辑器，直接回到 Baby；没有出现放弃草稿确认。随后对“关闭记录”的定位返回零个匹配，采集工具在发送点击前中止，因此 editor-close 只是同一 Baby 状态的复查，不能当作一次成功关闭操作。再点击 Me 恢复 Mia 首页。

前后 Baby / Mia 的 UI 树仅根 View 的 focused 从 false 变为 true；忽略这一属性后全部节点、文本、控件状态和边界一致。Baby 仍显示睡眠、尿湿、便便和吃奶未记录。整个链没有输入文字或保存操作，不产生测试健康记录；这不替代服务端数据库审计。

本批只补原生输入层，窗口不是长页面的完整截图。尿布各选项、记录保存、历史编辑及完整滚动长图见 [尿布控件报告](../../00-overview/BABY-DIAPER-CONTROLS.md)。大字键盘、输入到 2000 字、文本选择/粘贴、系统权限和 iOS 输入仍待覆盖。
