# Android Cozymate 与系统选择器

当前已安装 local App，20 张实际截图及对应 UI 树。原会话中已有失败回复及未发送草稿，本轮没有发送消息、读取系统剪贴板或清空会话。

照片选择器、Collections 和 Recent 文件选择器已实际打开并取消。首次相机授权弹窗已截取；使用系统返回取消后，App 显示“图片上传失败，请重试。”。授权前后 CAMERA 的 granted=false 及权限 flags 完全一致，未点击允许或拒绝按钮，也没有拍照。

长按用户消息后按系统返回，当前安装版本实际退出到 Android 桌面。重开 App 并返回 Cozymate，消息及草稿保持。没有取得对应原生日志异常，因此不将当前源码测试中的 GoRouter TypeError 直接认定为安装版退出的根因。再次打开菜单后点击外部可正常关闭。

最终恢复原妈妈首页，语义标签与操作前一致。以上是窗口证据；App 长对话完整拼接图见模块状态目录，不把系统窗口图称为长图。

| 状态 | 实际操作 | 截图 | UI 树 |
| --- | --- | --- | --- |
| conversation | 妈妈页 → Cozymate，保留原会话与未发送草稿 | [PNG](conversation.png) | [XML](conversation.xml) |
| attachment-menu | 添加附件 → 相机/照片/PDF 菜单 | [PNG](attachment-menu.png) | [XML](attachment-menu.xml) |
| photo-picker | 照片 → Android Photos 空列表 | [PNG](photo-picker.png) | [XML](photo-picker.xml) |
| photo-collections | Collections → 收藏与相机分类 | [PNG](photo-collections.png) | [XML](photo-collections.xml) |
| photo-return | 系统返回 → Photos 列表 | [PNG](photo-return.png) | [XML](photo-return.xml) |
| photo-cancelled | 再次返回 → 原会话，未选择照片 | [PNG](photo-cancelled.png) | [XML](photo-cancelled.xml) |
| file-menu | 再次打开附件菜单 | [PNG](file-menu.png) | [XML](file-menu.xml) |
| file-picker | 文件 → Android Recent 文件选择器，空列表 | [PNG](file-picker.png) | [XML](file-picker.xml) |
| file-cancelled | 系统返回 → 原会话，未选择文件 | [PNG](file-cancelled.png) | [XML](file-cancelled.xml) |
| camera-menu | 再次打开附件菜单 | [PNG](camera-menu.png) | [XML](camera-menu.xml) |
| camera-launch | 相机 → Android 首次相机权限申请 | [PNG](camera-launch.png) | [XML](camera-launch.xml) |
| camera-cancelled | 返回取消申请 → App 图片上传失败 Snackbar | [PNG](camera-cancelled.png) | [XML](camera-cancelled.xml) |
| message-menu | 长按原用户消息 → 复制菜单 | [PNG](message-menu.png) | [XML](message-menu.xml) |
| message-back | 系统返回 → App 离开前台，出现 Android 桌面 | [PNG](message-back.png) | [XML](message-back.xml) |
| reopened | 点击桌面 Momcozy Lab → 重新进入首页（XML 先记录加载态，截图时已载入） | [PNG](reopened.png) | [XML](reopened.xml) |
| reopened-mom | 资料读取完成 → 妈妈首页 | [PNG](reopened-mom.png) | [XML](reopened-mom.xml) |
| conversation-return | 再次进入 Cozymate → 原消息与草稿恢复 | [PNG](conversation-return.png) | [XML](conversation-return.xml) |
| message-menu-reopened | 再次长按同一用户消息 | [PNG](message-menu-reopened.png) | [XML](message-menu-reopened.xml) |
| menu-dismissed | 点击菜单外部 → 菜单关闭，会话保留 | [PNG](menu-dismissed.png) | [XML](menu-dismissed.xml) |
| restored-mom | Me → 返回原妈妈首页 | [PNG](restored-mom.png) | [XML](restored-mom.xml) |

[版本、前驱关系与哈希](evidence.json) · [原妈妈页](original-mom.xml) · [相机权限操作前](camera-permission-before.txt) · [操作后](camera-permission-after.txt)。
