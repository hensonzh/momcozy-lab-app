# Baby 发育观察：Android 放弃草稿与重新进入

使用现有 local App 的 Mia 会话和 Luna 资料，实际执行 Me → Baby → 滚动 → 记录发育观察 → 看向靠近的脸/观察到 → 关闭记录 → 离开 → 重新打开 → 未修改关闭 → Me。未点击保存，没有提交测试健康记录或改写用户资料。

11 张原生窗口均已查看，包含任务中断前后的起点证据。每张有 UI XML、SHA-256 和前驱动作；点击均匹配前一份 UI 树中的文字及边界。三组重复选项以实际观察到的第一组边界定位。上滑坐标从唯一 ScrollView 边界计算。

[逐步操作](actions.jsonl) · [证据审计](evidence.json) · [采集工具](capture_steps.py)

| 前驱 | 实际动作 | 截图 | UI 树 |
| --- | --- | --- | --- |
| 当前 App | 已有 Mia 登录会话 | [original-mom](original-mom.png) | [XML](original-mom.xml) |
| original-mom | 点击 Baby | [baby-entry](baby-entry.png) | [XML](baby-entry.xml) |
| baby-entry | 中断后重新观察，仍为 Baby | [resumed-baby](resumed-baby.png) | [XML](resumed-baby.xml) |
| resumed-baby | 在已观察的滚动区域上滑 | [baby-lower](baby-lower.png) | [XML](baby-lower.xml) |
| baby-lower | 点击记录发育观察 | [editor-empty](editor-empty.png) | [XML](editor-empty.xml) |
| editor-empty | 看向靠近的脸 → 观察到 | [editor-selected](editor-selected.png) | [XML](editor-selected.xml) |
| editor-selected | 点击关闭记录 | [discard-confirm](discard-confirm.png) | [XML](discard-confirm.xml) |
| discard-confirm | 点击离开 | [discarded-baby](discarded-baby.png) | [XML](discarded-baby.xml) |
| discarded-baby | 再次点击记录发育观察 | [reopened-empty](reopened-empty.png) | [XML](reopened-empty.xml) |
| reopened-empty | 未修改，点击关闭记录 | [unchanged-close](unchanged-close.png) | [XML](unchanged-close.xml) |
| unchanged-close | 点击 Me | [restored-mom](restored-mom.png) | [XML](restored-mom.xml) |

选择第一项后，该选项容器的 selected 属性由 false 变为 true，截图显示描边和填色。关闭后实际出现“离开这次记录？”以及“还未保存的修改会被放弃。”；点击“离开”后回到原 Baby 滚动位置。重新进入时三组均未选择，第一项 selected 恢复 false，观察日期保持当天；未修改关闭直接返回，没有再出现确认框。

忽略 focused 属性后，重新打开的编辑器与最初空编辑器 UI 树一致；放弃后与无修改关闭后的 Baby 页面均与原滚动位置一致。Mia 首页也已恢复，与最初 UI 树一致。原有 3.82 kg 记录仍显示；该值是已有数据，本批未创建或修改。以上为界面与操作链证据，不替代服务端数据库或网络写入审计。

本次原生编辑器在一个窗口内完整展示三组选项、日期、说明和保存动作。主页是滚动窗口截取，不能作为完整主页长图。393 px / 1x 与 320 px / 2x 的所有编辑控件、批量保存、历史编辑和完整长图见 [发育观察控件报告](../../00-overview/BABY-DEVELOPMENT-CONTROLS.md)。保存未确认后离开、保存中系统返回、权限/冲突、日期边界和删除恢复仍待覆盖。
