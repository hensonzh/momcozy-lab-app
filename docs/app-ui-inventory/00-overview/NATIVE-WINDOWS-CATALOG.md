# G10：原生窗口证据总表

本项已完成归并：固定队列中的系统键盘、照片／文件选择器、通知权限／系统设置、相机／麦克风授权均有真实 Android 窗口。另保留外部浏览器落地和返回证据。15 张现有完整窗口已重新目视检查，没有新建平台、设备或权限交叉组合。

本表复用的是各原报告记录的 Android 运行证据，不声称后方 App 旧布局已更新，也不将宿主 Widget 的键盘占位或权限替身当成系统截图。不同业务入口调用同一系统窗口时只引用已有类别与各自操作链。

| 系统窗口／状态 | 原入口与实际操作 | 完整窗口与 UI 树 | 原证据 |
| --- | --- | --- | --- |
| Android 首次通知申请（拒绝恢复链） | App Continue → actual Android request; choose deny | [图](../native/notification-permission/native-permission-deny-system-request.png) · [XML](../native/notification-permission/native-permission-deny-system-request.xml) | [版本与路径](../native/permission-manifest.json) |
| Android 通知总开关关闭（拒绝恢复链） | App Open settings → Android notification master switch off | [图](../native/notification-permission/native-permission-deny-system-settings-off.png) · [XML](../native/notification-permission/native-permission-deny-system-settings-off.xml) | [版本与路径](../native/permission-manifest.json) |
| Android 通知总开关开启（拒绝恢复链） | Turn on Android master switch → enabled; system Back returns to App | [图](../native/notification-permission/native-permission-deny-system-settings-on.png) · [XML](../native/notification-permission/native-permission-deny-system-settings-on.xml) | [版本与路径](../native/permission-manifest.json) |
| Android 首次通知申请（首次允许链） | App Continue → actual Android request; choose allow | [图](../native/notification-permission/native-permission-allow-system-request.png) · [XML](../native/notification-permission/native-permission-allow-system-request.xml) | [版本与路径](../native/permission-manifest.json) |
| Android 摄像头申请（拒绝） | Actual Android camera permission → choose deny | [图](../native/consultation-devices/native-device-deny-camera.png) · [XML](../native/consultation-devices/native-device-deny-camera.xml) | [版本与路径](../native/device-manifest.json) |
| Android 麦克风申请（拒绝） | Actual Android microphone permission → choose deny | [图](../native/consultation-devices/native-device-deny-microphone.png) · [XML](../native/consultation-devices/native-device-deny-microphone.xml) | [版本与路径](../native/device-manifest.json) |
| Android 再次申请摄像头（允许） | Actual Android camera permission → choose allow | [图](../native/consultation-devices/native-device-allow-camera.png) · [XML](../native/consultation-devices/native-device-allow-camera.xml) | [版本与路径](../native/device-manifest.json) |
| Android 再次申请麦克风（允许） | Actual Android microphone permission → choose allow | [图](../native/consultation-devices/native-device-allow-microphone.png) · [XML](../native/consultation-devices/native-device-allow-microphone.xml) | [版本与路径](../native/device-manifest.json) |
| photo-picker | 照片 → Android Photos 空列表 | [图](../native/agent/photo-picker.png) · [XML](../native/agent/photo-picker.xml) | [版本与路径](../native/agent/evidence.json) |
| photo-collections | Collections → 收藏与相机分类 | [图](../native/agent/photo-collections.png) · [XML](../native/agent/photo-collections.xml) | [版本与路径](../native/agent/evidence.json) |
| file-picker | 文件 → Android Recent 文件选择器，空列表 | [图](../native/agent/file-picker.png) · [XML](../native/agent/file-picker.xml) | [版本与路径](../native/agent/evidence.json) |
| camera-launch | 相机 → Android 首次相机权限申请 | [图](../native/agent/camera-launch.png) · [XML](../native/agent/camera-launch.xml) | [版本与路径](../native/agent/evidence.json) |
| 软件键盘 | 宝宝资料 → 昵称 → 输入工具条菜单 → Show on-screen keyboard | [图](../native/baby-profile-software-keyboard.png) · [XML](../native/baby-profile-software-keyboard.xml) | [版本与路径](../native/README.md) |
| 输入工具条菜单 | 宝宝资料 → 昵称 → 输入工具条菜单 | [图](../native/baby-profile-input-menu.png) · [XML](../native/baby-profile-input-menu.xml) | [版本与路径](../native/README.md) |
| 外部浏览器已加载 | Baby 知识卡 → WHO 来源 → 关闭 Chrome 引导 | [图](../native/knowledge-source/external-page.png) · [XML](../native/knowledge-source/external-page.xml) | [版本与路径](../native/knowledge-source/evidence.json) |

## 操作链与完整性

- [键盘原链](../native/README.md)与[尿布输入返回链](../native/baby-diaper-input/README.md)：完整软件键盘由浮动工具条菜单展开。XML 仅包含 App 无障碍节点时，键盘存在以真实屏幕为证，不以包名推断；工具条和键盘分别归档。
- [照片／文件／相机入口](../native/agent/README.md)：照片选择器包含 Photos 和 Collections，文件 Recent 为空；均实际取消返回。相机入口当时取消权限，后续咨询设备链已覆盖同类系统授权的允许与拒绝。
- [通知允许与拒绝恢复](NATIVE-NOTIFICATION-PERMISSIONS.md)：真实系统申请、拒绝、打开系统设置、实际切换总开关、返回和刷新；App 分类与系统授权分开记录。
- [摄像头与麦克风](NATIVE-CONSULTATION-DEVICES.md)：真实拒绝、重试允许、本地轨道检测成功并释放。不同业务服务的视频授权仍是独立 App 界面。
- [外部浏览器](../native/knowledge-source/README.md)：WHO 落地页实际加载并返回原文章；仅记录交接窗口，不扩展为第三方网站全站截图。

通知、相机、麦克风授权的前后画面并不新增独立 App 页面。相同弹窗在允许／拒绝链中的原图都保留用于追踪，主浏览清单共享类别。系统设置关闭／开启有实际可见差异，分别保留。

## 平台边界

现有原生证据来自 Android 模拟器。未把它声明为 iOS 图；本次用户要求未新增多平台验收矩阵。真实 Google 账号选择、真实推送投递、系统相机拍照和第三方浏览器内全部操作也不由本表证明。Google 当前不可用反馈已有 App 图，不通过配置真实账户制造额外截图。媒体上传成功、错误、取消等 App 状态仍归各自页面。

[逐图哈希、XML 所属包与来源](native-window-reuse.json)保留可复核记录。系统窗口均以完整屏幕保存；其背景 App 长页面以模块完整长图为准，不拼接背景冒充系统浮层长图。原生图代表既有系统类别，不替代 G11 对当前 App 布局的版本检查。
