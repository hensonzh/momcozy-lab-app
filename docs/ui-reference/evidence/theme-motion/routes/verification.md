# 减少动态效果：普通路由与通用弹层

依据：重新阅读生活陪伴型 Design System 中“减少动态效果设置下不执行非必要动画”的验收要求，以及公共确认的衍生规范。只调整过渡行为，未修改页面业务条件。

- 用户 App 的 PageTransitionsTheme 继续委托 Flutter 当前平台的过渡实现；减少动态效果时传入已完成的视觉状态。保留平台原有导航控制器和 iOS 返回手势。普通模式的时长和曲线保持原样。
- 27 个用户 App / 共用文件的 39 处 showDialog、showModalBottomSheet 调用接入统一 AnimationStyle。启用减少动态效果时使用 noAnimation，普通模式传 null，沿用 SDK 默认值。未修改 IBCLC 专属页面或其应用主题。
- `before.txt` 捕获确认弹窗、语言弹层在两个无耗时帧后仍未完成的原始失败；`component.txt` 六项通过，覆盖两平台普通/减少动态效果、iOS 边缘滑动返回、弹窗取消与弹层系统返回。
- `regression.txt`：1,020 项检查通过，覆盖共享组件、认证、首次使用、通知、Agent、Baby、妈妈、隐私、服务、日程和咨询模块。
- `analyze.txt`：lib 和新增组件测试静态检查无问题。
- `native.txt`：Android 模拟器 1x/2x 字号验证通过。实际确认组件和语言组件在两个无耗时帧后完整显示，取消返回 false，页面往返和系统返回正常。截图显示标题、说明、操作按钮和语言选项没有裁切。登录头部仅作为路由与弹层的测试载体，截图不是完整登录页验收。
- `build.txt`、`install.txt`：普通 local APK 构建并覆盖安装成功，已恢复 Mia 登录首页，见 `native-restored-home.png` 和对应 XML。`native-analyze.txt` 记录原生测试文件静态检查通过。

原生测试通过 MediaQuery 注入减少动态效果，不修改设备的系统设置，也不调用账号或业务保存 API。普通页面的导航控制器仍按平台周期运行；本轮验证的是视觉位置稳定和导航交互，不能将其描述为所有路由控制器时长均为零。

日期和时间选择器不在上述 39 处通用弹层中；后续已统一其 12 处入口并验证，见 [选择器复核](../pickers/verification.md)。Typography 覆盖关系仍待核对，公共 Theme 保持 Need Review。
