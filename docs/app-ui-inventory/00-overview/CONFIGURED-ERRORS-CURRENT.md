# G11：配置页错误反馈已对应

最终合并复验：4 个具名场景全部严格通过，6 张完整图。[最终运行](runs/20260914T092346-g11-configured-final/strict-capture.log) · [当前图片与指纹](runs/20260914T092346-g11-configured-final/reviewed-images.json) · [源码范围](runs/20260914T092346-g11-configured-final/g11-audit.json)。头像上传等待图补齐本地插图解码后更新；[此前尚未解码的图](runs/20260914T092346-g11-configured-final/previous-upload-pending-before-asset-decoded.png)归档保留。下方分批结果保留原范围。

具名剩余反馈已实际操作：邀请码设备限制、本机登录保存失败、头像上传失败、默认形象保存失败。两个定向场景严格通过，实际查看 3 张完整图；未增加尺寸、错误码或请求时序组合。

| 界面 | 截图 | 操作及后续 |
| --- | --- | --- |
| 邀请码已在其它设备使用 | [图](../01-auth/auth-invite-device-error/default.png) | 正式登录页提交被拒，邀请码保留，可重新提交 |
| 服务端认证成功但本机会话保存失败 | [图](../01-auth/auth-invite-storage-error/default.png) | 显示重启提示，保持未登录；存储恢复后再提交进入 `/more` |
| 头像创建页请求失败 | [图](../01-auth/onboarding-request-error/default.png) | 实际选图后上传失败；再选择默认形象并确认，保存失败。两条链使用相同服务端消息时严格匹配同一张图；默认保存恢复后进入 `/more` |

两个头像失败入口复用一个代表图，不声称任意服务端文案都一样。其它文案沿当前错误展示组件归属，不枚举 HTTP 错误码。图片为实际 App 路由和生产页面，API、选图和存储均用隔离 fixture；不代表系统窗口或真实服务故障。照片选择错误、候选确认失败及成功激活继续引用 [既有配置证据](CONFIGURED-PAGES-CURRENT.md) 与 [上轮提交报告](CONFIGURED-SUBMISSION-CURRENT.md)。

头像错误图初次严格比较发现插图解码尚未完成，差异只在插图区；补等待本地图片解码后，两条错误链严格匹配原已生成金图。未修改产品代码。

[严格运行](runs/20260914T091823-g11-configured-errors/strict-capture.log) · [图片检查](runs/20260914T091823-g11-configured-errors/reviewed-images.json) · [范围和源码](runs/20260914T091823-g11-configured-errors/g11-audit.json) · [静态分析](runs/20260914T091823-g11-configured-errors/analyze.log)。本项具名反馈已关闭，最终全状态映射另行验收。
