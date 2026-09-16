# Android 日程实际入口

当前已安装 local App：妈妈页 → Schedule → 添加日程 → 日期/取消 → 时间/取消 → 关闭 → 原日程 → 原妈妈页。8 张截图及 UI XML 保留真实布局、系统状态栏和输入工具条。未输入文本、未保存或删除；原日程与返回日程语义标签一致，妈妈页恢复标签一致。

这是当前安装版本的实际运行证据，未重新构建，也不代表所有隔离数据场景在真实账号上执行。新增表单中可见模拟器输入工具条，不能将其称为完整软键盘。原妈妈页仅用于证明恢复，不作为完整首页长图。

| 状态 | 实际动作 | 截图 | UI 树 |
| --- | --- | --- | --- |
| agenda | Mom → Schedule bottom navigation | [PNG](agenda.png) | [XML](agenda.xml) |
| create-empty | Add schedule → empty focused form | [PNG](create-empty.png) | [XML](create-empty.xml) |
| date-picker | Tap date → calendar dialog | [PNG](date-picker.png) | [XML](date-picker.xml) |
| date-cancelled | Cancel calendar → date unchanged | [PNG](date-cancelled.png) | [XML](date-cancelled.xml) |
| time-picker | Tap start time → clock dialog | [PNG](time-picker.png) | [XML](time-picker.xml) |
| time-cancelled | Cancel clock → time unchanged | [PNG](time-cancelled.png) | [XML](time-cancelled.xml) |
| agenda-return | Close unchanged form → original agenda | [PNG](agenda-return.png) | [XML](agenda-return.xml) |
| restored-mom | Me bottom tab → original Mom page | [PNG](restored-mom.png) | [XML](restored-mom.xml) |

[版本、前驱关系与 SHA-256](evidence.json)；[操作前妈妈页 UI 树](original-mom.xml)。
