# G12：配置页面当前代表证据

4 个配置页面已单列归档，复用 11 个既有视觉场景、25 张完整图，其中 9 张为测量滚动后的完整长图。没有新增测试用例、尺寸组合或更新截图基线。此项关闭配置页面归档缺口，不将默认关闭的入口计作正常构建缺页，也不将旧批次所有状态标成当前版本。

| 页面 | 启用条件与入口 | 本次归档范围 |
| --- | --- | --- |
| 邀请登录 | internalInviteOnly 配置的登录入口 | 邀请码表单、空值校验与短键盘占位 |
| 首次使用资料 | onboardingGateEnabled 启用后的引导 | 加载及重试、基本资料、出生日期及校验、分娩资料、日期输入、保存等待与失败草稿 |
| 数字形象创建 | 配置开启后的 /avatar/create 或引导 | 必需选择、照片入口、默认确认、生成中、失败与重试；任务横幅另作共享组件证据 |
| 数字形象确认 | 配置开启后的 /avatar/review 或引导 | 候选、选择与页面底部、缩略图失败、确认等待及失败 |

两个已有 App 启动用例另行通过：默认配置不会请求 onboarding 资源且进入妈妈首页；显式启用 onboardingGateEnabled 时请求引导资源并出现资料表单。它们证明配置开关行为，不代表本次重新遍历了每条数字形象深链。页面状态采用真实生产 Widget，网络、图片和平台依赖使用测试实现，不声称完成真实云端形象生成或照片上传。

## 完整图

| 具名状态 | 完整图 | 长页 |
| --- | --- | --- |
| auth-invite | [查看](../raw/test/goldens/design_system/auth-invite-390.png) | 无纵向溢出 |
| auth-invite-validation | [查看](../raw/test/goldens/design_system/auth-invite-validation-390.long.png) | 完整长图 |
| onboarding-avatar-short-confirm-busy | [查看](../raw/test/goldens/design_system/onboarding-avatar-short-confirm-busy-320-2x.long.png) | 完整长图 |
| onboarding-avatar-short-confirm-error | [查看](../raw/test/goldens/design_system/onboarding-avatar-short-confirm-error-320-2x.long.png) | 完整长图 |
| onboarding-avatar-short-image-error | [查看](../raw/test/goldens/design_system/onboarding-avatar-short-image-error-320-2x.long.png) | 完整长图 |
| onboarding-banners | [查看](../raw/test/goldens/design_system/onboarding-banners-390.png) | 无纵向溢出 |
| onboarding-basics | [查看](../raw/test/goldens/design_system/onboarding-basics-390.png) | 无纵向溢出 |
| onboarding-birth | [查看](../raw/test/goldens/design_system/onboarding-birth-390.png) | 无纵向溢出 |
| onboarding-birth-error | [查看](../raw/test/goldens/design_system/onboarding-birth-error-390.png) | 无纵向溢出 |
| onboarding-default-confirm | [查看](../raw/test/goldens/design_system/onboarding-default-confirm-390.png) | 无纵向溢出 |
| onboarding-delivery | [查看](../raw/test/goldens/design_system/onboarding-delivery-390.png) | 无纵向溢出 |
| onboarding-failed | [查看](../raw/test/goldens/design_system/onboarding-failed-390.png) | 无纵向溢出 |
| onboarding-failed-source | [查看](../raw/test/goldens/design_system/onboarding-failed-source-390.png) | 无纵向溢出 |
| onboarding-generating | [查看](../raw/test/goldens/design_system/onboarding-generating-390.png) | 无纵向溢出 |
| onboarding-load-error | [查看](../raw/test/goldens/design_system/onboarding-load-error-390.png) | 无纵向溢出 |
| onboarding-loading | [查看](../raw/test/goldens/design_system/onboarding-loading-390.png) | 无纵向溢出 |
| onboarding-photo-error | [查看](../raw/test/goldens/design_system/onboarding-photo-error-390.png) | 无纵向溢出 |
| onboarding-required | [查看](../raw/test/goldens/design_system/onboarding-required-390.png) | 无纵向溢出 |
| onboarding-required-source | [查看](../raw/test/goldens/design_system/onboarding-required-source-390.png) | 无纵向溢出 |
| onboarding-review | [查看](../raw/test/goldens/design_system/onboarding-review-390.long.png) | 完整长图 |
| onboarding-review-footer | [查看](../raw/test/goldens/design_system/onboarding-review-footer-390.long.png) | 完整长图 |
| onboarding-review-selected | [查看](../raw/test/goldens/design_system/onboarding-review-selected-390.long.png) | 完整长图 |
| onboarding-short-busy | [查看](../raw/test/goldens/design_system/onboarding-short-busy-320-2x.long.png) | 完整长图 |
| onboarding-short-date-input | [查看](../raw/test/goldens/design_system/onboarding-short-date-input-320-2x.png) | 无纵向溢出 |
| onboarding-short-error | [查看](../raw/test/goldens/design_system/onboarding-short-error-320-2x.long.png) | 完整长图 |

已检查长页全部字段、候选列表、错误提示及底部提交区；不以首屏代替完整页面。相同返回页和多个入口继续共享总清单代表图，旧截图不删除。系统键盘／照片选择窗口引用 [G10](NATIVE-WINDOWS-CATALOG.md)，不把 Widget 占位当成系统截图。

## 验证记录与版本边界

- [首次运行](runs/20260914T082426-configured-pages-current/capture.log)：11 个视觉场景通过；单独的 capability gate 测试文件受到同期 Agent 源文件编译错误影响，整次退出码为 1，未记为全绿。
- [只重跑两项配置开关检查](runs/20260914T082659-configured-gates-current/capture.log)：同期 Agent 编译问题消失后通过，退出码 0。本盘点未修改该产品文件，也没有重跑已通过的视觉场景。
- [逐图指纹与范围](runs/20260914T082659-configured-gates-current/g12-audit.json)：上述图片、页面及共用 Widget 源码与采集快照一致。头像目录的较新实现指纹用于整个 onboarding 文件，较早 profile 报告不自动变成当前版本。

配置入口已单列；其余历史提交／失败等状态是否需要更新，仍由 [G11 具名核对清单](REMAINING-VISUAL-REVIEW.md) 收口，禁止沿配置页面另加组合矩阵。
