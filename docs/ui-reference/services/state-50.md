# 咨询准备-恢复授权去向

- ID：`services/state-50`
- 类型：state
- 参考来源：original
- 设计源码：[PrivacyPage](../source/src/pages/UserApp.tsx#L1970)，第 1970–2068 行
- Flutter：`lib/modules/profile/presentation/privacy_page.dart`
- Route / 入口：`/privacy`
- 触发：视频授权已撤回 → 去授权
- 状态：**Need Review**

设计中去授权打开完整 PrivacyPage；本次服务的视频授权衍生弹窗不能计作此全局五项隐私设置完成。

[查看参考图](../services/reference/state-50.png)

原始路径：`me-ui-optimization/05-validation/images/50-咨询准备-恢复授权去向.png`；SHA-256：`67bf74265d46fca67d62b6e611275950b33da0f6b3f469bca0f61cec593b4059`。

[查看参考图](../services/state-50-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`9b522c8ef7f217312a5e908ce184c2d703d2a9ec5df934bd3e0b059d7bcce3f2`。


验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
