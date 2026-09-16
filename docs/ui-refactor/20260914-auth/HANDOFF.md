# 登录、邮箱验证与账号返回状态

本轮完成现有 [68 个源截图条目](source-inventory.json) 对应的认证页面重构，其中 57 个属于认证目录，11 个是账号删除、退出登录后实际返回 `/login` 的状态。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=224-1108) 设计登录、注册、邮箱验证、找回及重置密码、邀请码、语言与失败状态，再落实 Flutter。最终保留 [37 个画板](figma-nodes.json)，包括短屏大字号和返回登录提示。

页面现在复用母亲端背景、玫瑰色操作、薄荷色提示、22 圆角卡片和 NotoSansSCHome 字体。品牌字样保留 Libre Caslon Display；母婴插画缩至 48，Google 继续使用原正式资产。登录欢迎区和表单分开，错误及成功提示有独立区域，Google 错误仍位于 Google 按钮和邮箱输入之间。所有字段、辅助文字、验证码操作和条款均在原滚动容器内；大字号欢迎区将插画排在正文下方，语言弹层增加滚动支持。邀请码入口使用相同框架，现有中文内容保留。

沿用最新母亲端视觉要求，因此任务标题改用共享字体，旧登录参考中的品牌字样和资产仍保留。没有增加第三方登录方式、语言选项或验证步骤。输入框密码显隐、自动填充、焦点、键盘行为及系统条款打开流程仍使用原 Flutter/平台控件；Figma 是布局和状态参考，系统控件细节以实际渲染为准。

验证结果：

- [23 项专项检查通过](design-states-test.log)：320/390/430 屏宽、1×/2× 字号，登录、注册、密码校验、邮箱验证、找回密码、重置、邀请码及语言。新增 320×568、2× 字号下的请求锁定、失败后保留字段重试、无效和过期验证码、重发冷却、缺少邮箱、重发忙碌、Google 失败恢复及会话持久化失败检查。
- [83 项联测通过](joint-tests.log)，覆盖认证页面、账号页面、账号确认弹层、认证接口、会话生命周期、刷新与安全存储；[5 个文件静态分析通过](analyze.log)。没有运行写入 Session A 清单的 inventory 测试。
- [8 项行为对比全部一致](behavior-checks.json)：导航与步骤文案、网络请求和忙碌处理、验证码冷却及重发、Google 登录、会话保存与失败撤销、错误映射、邀请码恢复与设备绑定、外部条款链接，以及邮箱/验证码/密码校验。对比忽略 Dart 格式化的空白和尾逗号；业务方法保留。

已目视核对 [Figma 登录](figma/login.png)、[大字号](figma/large-login.png)、[验证邮箱](figma/verify.png)、[语言](figma/language.png)、[账号删除返回](figma/deleted-login.png)，以及 Flutter 的 [登录](verified/auth-login-390.png)、[大字号登录](verified/auth-login-320-2x.png)、[邮箱验证](verified/auth-verify-320.png)、[邀请码](verified/auth-invite-320-2x.png)、[语言](verified/auth-language-320-2x.png)、[验证码校验](verified/auth-code-validation-320-2x-short.png) 和 [重发忙碌](verified/auth-resend-busy-320-2x-short.png)。部分截图保留测试中的实际滚动位置，短屏页面仍可继续滚动。

账号删除和退出登录的请求、路由及 Snackbar 由现有账号/更多页与运行时提供，没有改写。对应 11 个源条目已复核为登录页目的状态，从待核对队列移出，剩余 31 项。登录仍保留会话过期、密码重置完成以及三种不同的删除/登出结果文案。

[清单检查](inventory-delta.json) 仍为 2675 个状态，无新增、变更或删除；这不是页面完成比例。[源图及元数据指纹](source-image-hashes.json)、[实现指纹](implementation-hashes.json) 和修改前副本已保存。此次验证为本地 Flutter widget/golden 与静态分析，未进行原生设备重新采集、构建或发布。整体重构任务保持 active，下一候选是已有截图的首次使用引导。
