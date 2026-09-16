# Android 通知与系统设置实际入口

本次使用当前已安装的 `com.momcozymai.app.flutterpoc.local`，从原先的 Baby 页进入 More → 通知 → Notification settings → Settings → Android 应用通知设置，再沿返回键回到 App，最终恢复 Baby 页。没有重建/安装 App，没有退出账号或修改通知偏好、系统权限。

| 步骤 | 实际界面 | 证据 |
| --- | --- | --- |
| Baby → More | 原登录账号的更多页 | [截图](more-entry.png) / [层级](more-entry.xml) |
| 更多 → 通知 | 空消息中心 | [截图](inbox-empty.png) / [层级](inbox-empty.xml) |
| 消息中心 → 设置 | 系统 Not requested；四类偏好仍开；本地后台推送不可用 | [截图](settings-not-requested.png) / [层级](settings-not-requested.xml) |
| App Settings → 系统 | Android 应用通知总开关关闭 | [原生截图](android-notifications-off.png) / [系统层级](android-notifications-off.xml) |
| 系统返回 App | 权限仍 Not requested，四类偏好值不变 | [截图](settings-return.png) / [层级](settings-return.xml) |
| 返回原 Baby 页 | 保留原账号与宝宝，未修改资料 | [恢复窗口](returned-baby.png) / [层级](returned-baby.xml) |

设备版本、步骤前驱和 PNG 哈希见 [evidence.json](evidence.json)。系统设置页内容未超出一屏；App 设置页的 Refresh status 底部按钮在截图内完整可见。Baby 恢复图仅证明返回状态，不作为宝宝长页面完整截图。

这是原生系统设置入口的证据，**不等于**通知首次申请的 Allow/Don't allow 原生弹窗、系统通知实际投递/点击或 iOS 权限已经验证。这些仍在总盘点待办中。当前本地构建明确提示后台推送不可用；隔离测试中的推送就绪状态不代表本地配置已开通。


## 后续首次权限补验

上文保留首次只读入口观察的原始边界。后续实际运行已补齐首次 Allow / Don’t allow、拒绝后打开系统总开关及返回 App 的完整流程；见 [原生权限报告](../../00-overview/NATIVE-NOTIFICATION-PERMISSIONS.md)。不将隔离推送 Gateway 视为真实投递成功。
