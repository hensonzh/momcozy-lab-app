# 咨询房间离开失败与重试

范围为用户 App 的离开确认及恢复状态。修改前重新读取设计 `UserApp.tsx` VideoPage（3730–3810）：先断开媒体，leave 成功后才返回主页，暂时离开不结束咨询。确认弹窗沿用 `services/room-leave-viewport.png`；原稿无断开异常的独立稿，错误提示属于用户批准的**衍生设计**，复用现有琥珀色状态卡、正文及 liveRegion。

## 已验证的问题与修复

首次新增测试在原实现中失败：disconnect 抛错未经页面处理，`_leaving` 未释放，`_connectionId` 已被清除，后续无法再次离开。原始失败见 before.log。

页面现在捕获断开异常，在 finally 中释放离开操作锁；保持当前页面并展示“暂时无法离开咨询室，请再次点击离开房间重试。”。重试成功后才允许导航。错误提示保留到下次重试，不被定时刷新覆盖，不展示底层错误内容。

控制器在 disconnect 期间仍暂停 presence 上报；如果媒体断开失败，恢复同一代连接及上次上报时间，以便重试后对原连接发送 left。页面已销毁或连接代次已变化时，不恢复旧连接。没有改动 Backend/API、end 操作或收费逻辑。

补充可见性测试发现 320 宽双倍字号下提示顶部可能位于视口之外（visibility-before.log）。失败后等待布局完成，将提示滚入可见区域；没有依靠测试主动滚动来证明用户可见。

## 验证范围

- 两项控制器测试：失败后保留连接并重试，销毁后到达的失败不复活旧连接。
- 320 / 390 / 430 × 1x / 2x：失败提示、刷新后仍存在、提示实际可见、再次确认、重试成功、只上报一次 left、无 end 调用；12 张渲染基线。
- 咨询模块和路由契约共 109 项通过，见 regression.log。
- Android 使用真实页面、控制器和原生交互，媒体/仓储为受控替身；首次断开抛错、第二次成功。正常/双倍字号的失败提示及重试确认截图见 native-room-leave-*.png。此项不代表真实 LiveKit 故障注入或双端媒体联调通过。
- 原生验证后，静态分析要求对提示自身的 BuildContext 补充 mounted 判定；补齐后 5 文件分析无问题、8 项针对性测试复验通过，既有 12 张基线不变（analyze.log、component-final.log）。这一补充不改变已截取的布局与交互。
- 最终普通本地 Debug APK 构建成功并重新安装，模拟器恢复 Mia 妈妈主页；见 build.log、install.log、native-restored-home.png / .xml。

咨询房间的正常结束后 Cozymate 上下文交接仍缺少契约；`services/room` 保持 Need Review。本轮完成的是离开异常恢复，`services/room-leave` 保留 Completed 并补充证据。
