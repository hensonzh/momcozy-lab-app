# G11：配置页面的 3 个具名缺图已补齐

最终合并复验：4 个具名场景全部严格通过，6 张完整图。[最终运行](runs/20260914T092346-g11-configured-final/strict-capture.log) · [当前图片与指纹](runs/20260914T092346-g11-configured-final/reviewed-images.json) · [源码范围](runs/20260914T092346-g11-configured-final/g11-audit.json)。头像上传等待图补齐本地插图解码后更新；[此前尚未解码的图](runs/20260914T092346-g11-configured-final/previous-upload-pending-before-asset-decoded.png)归档保留。下方分批结果保留原范围。

邀请码提交中、头像上传中、生成交接弹窗三张图已采集并实际查看。两个定向场景严格比较通过，未增加尺寸、错误码或请求时序矩阵。三张均为 390×844 完整页面／弹窗，没有活动纵向溢出，因此不需要长图拼接。

| 页面／状态 | 真实入口与操作 | 完整图 | 后续结果 |
| --- | --- | --- | --- |
| 邀请登录提交中 | 开启邀请配置 → `/login?from=/more` → 输入邀请码 → 提交 | [截图](../01-auth/auth-invite-submit-pending/default.png) | 服务返回后本机会话已认证，正式路由进入 `/more` |
| 头像上传中 | 提供 onboarding controller → 从 `/more` 重定向到 `/onboarding` → Upload a photo → Choose from library | [截图](../01-auth/onboarding-upload-pending/default.png) | 真实 repository 接受照片并提交生成请求，进入交接弹窗 |
| 生成交接弹窗 | 上传完成、生成排队 → Your digital companion is being created | [截图](../01-auth/onboarding-generation-handoff/default.png) | Wait here 关闭弹窗并留在 `/onboarding`；Enter the app 关闭弹窗并进入 `/more`。两个按钮都实际点击，只保存一张共同界面 |

使用真实 `MomCozyFlutterApp`、路由、页面、controller 和 repository；HTTP 与系统选图输入使用隔离 fixture。不是系统相册截图，也不证明云端实际生成完成。系统选择器继续引用 [既有原生证据](NATIVE-WINDOWS-CATALOG.md)。配置启用条件仍单列，不计入默认构建页面缺图。

只新增 [定向采集场景](../../../test/features/onboarding/configured_submission_inventory_test.dart)及三张基线，未修改产品代码。第一次场景使用了不匹配的选择器文案，第二次等待了不会停止的生成进度动画；最终改用现有控件 key 和固定动画推进，不修改产品行为。最终采集未更新金图。

[静态分析](runs/20260914T091054-g11-configured-submission/analyze.log) · [严格运行](runs/20260914T091054-g11-configured-submission/strict-capture.log) · [命令与配置](runs/20260914T091054-g11-configured-submission/commands.json) · [逐图检查](runs/20260914T091054-g11-configured-submission/reviewed-images.json) · [版本和路由证明](runs/20260914T091054-g11-configured-submission/g11-audit.json)。

本报告只关闭 3 个具名缺图。邀请失败和头像失败的证据对应、Agent 版本，以及全盘状态和入口映射仍见 [判定清单](CAPTURE-DECISIONS.md)，不据此宣布整个 UI 盘点完成。
