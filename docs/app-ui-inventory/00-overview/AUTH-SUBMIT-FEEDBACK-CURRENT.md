# G11：认证提交状态与共享反馈核对

已关闭注册提交中、注册邮件服务失败、验证码提交中这 3 个具名缺图。新增一个标准窗口下的定向操作链，只创建对应 3 张图；未扩展尺寸或错误码矩阵。共享反馈复用 4 张现有严格金图及 G05 日程错误长图；续购空态作为页面自有卡片参考，不能冒充 ProductEmptyView。

## 实际操作链

未登录打开 More → 登录页 → Create an account → 填写邮箱与密码 → 注册提交等待（按钮禁用）→ 邮件服务失败（输入保留、恢复重试）→ 重试进入邮箱验证 → 输入验证码 → 提交等待 → 验证成功，真实路由到 More，运行时会话已认证。网络、存储与平台使用隔离实现。

注册／验证默认表单、字段校验、重发、过期验证码、退出以及登录、找回、重置见 [G04 当前证据](AUTH-CURRENT.md)；登录后相同 More 页面沿用已有图，没有新增重复到达图。

| 状态 | 完整图 |
| --- | --- |
| auth-followup-register-pending-393-1x | [查看](../raw/test/goldens/ui_inventory/auth-followup-register-pending-393-1x.png) |
| auth-followup-register-email-unavailable-393-1x | [查看](../raw/test/goldens/ui_inventory/auth-followup-register-email-unavailable-393-1x.png) |
| auth-followup-verify-submit-pending-393-1x | [查看](../raw/test/goldens/ui_inventory/auth-followup-verify-submit-pending-393-1x.png) |
| feedback-loading-390 | [查看](../raw/test/goldens/design_system/feedback-loading-390.png) |
| feedback-empty-390 | [查看](../raw/test/goldens/design_system/feedback-empty-390.png) |
| feedback-offline-390 | [查看](../raw/test/goldens/design_system/feedback-offline-390.png) |
| feedback-conflict-390 | [查看](../raw/test/goldens/design_system/feedback-conflict-390.png) |
| schedule-short-refresh-error.long | [查看](../raw/test/goldens/design_system/schedule-short-refresh-error.long.png) |
| renew-empty-390 | [查看](../raw/test/goldens/design_system/renew-empty-390.png) |

9 个完整窗口已目视检查，含 1 张复用长图；新认证图均无纵向溢出，完整显示提示、输入框、提交与返回区。共享普通错误的草稿文案／重试、冲突的重新载入、左对齐空态及带标签加载均严格匹配原图。Mom 风格错误沿用 [日程当前图](SCHEDULE-CURRENT.md)，其共享组件源码指纹与本次一致。各宿主的旧布局仍按 G11 剩余表核对，不能因此批组件图通过而自动清除全 App 旧状态。

- [严格运行记录](runs/20260914T083633-g11-auth-feedback/strict-capture.log)：两个定向场景通过。
- [静态分析](runs/20260914T083633-g11-auth-feedback/analyze.log)：通过。
- [具名范围与源码快照](runs/20260914T083633-g11-auth-feedback/g11-audit.json) · [逐图哈希及长图测量](runs/20260914T083633-g11-auth-feedback/reviewed-images.json)。

本次没有修改产品代码；仅修改认证采集用例并建立 3 张缺失基线。首次尝试将更新基线与严格采集同时开启，被采集器拒绝；随后按独立基线创建、严格复验顺序通过，没有绕过比较。
