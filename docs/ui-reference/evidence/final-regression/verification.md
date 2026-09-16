# 用户 App 整体验证与参考库复核

范围为用户 App。专家工作台继续单列在 `../../workbench/`，不计入本次 147 个页面、组件及状态条目。

## 全量回归

首次执行记录见 `initial.log`：1,723 项通过，6 项失败，全部为真实 PDFium 文档预览的截图比较。检查普通及 2x 字号的实际差异，标题已经继承此前确认的 Manrope 主题，旧基线仍为 DM Sans；PDF 正文、分页、缩放工具没有新增布局变更。

重新阅读 `../../common/derived/pdf.md`、统一标题规范和 MediaViewerHeader 实现后，仅更新六张 `media-pdf-loaded-*` 基线。`pdf-baseline-update.log` 中六项通过，包括真实文档绘制、前后翻页边界、按钮缩放、拖动和双击缩放。更新模式的通过不作为最终回归通过；普通模式全量复跑结果单独保存在 `final.log`。

最终普通模式全量复跑 **1,729 项全部通过**，包含六项 PDFium 检查，耗时53秒。`git diff --check` 无问题（`diff-check.log` 为空）。未提高截图容差或跳过失败用例。

本轮没有修改产品代码，没有重新构建或安装 App；沿用上一轮已构建并恢复 Mia 账号的普通本地 App。构建与设备证据见 `../onboarding-reading/verification.md`。本地夹具及组件测试不代表 Google、邮件、支付或远程视频提供商已验收。

## 参考与证据

`reference-audit.json` 检查设计源文件、参考图片、已完成条目的功能/视觉证据以及用户 App 文件映射。源文件当前内容以 `../../source-manifest.json` 的源路径和 SHA-256 为准。

结果为 **Total Pages 147 / Completed 142 / Need Review 5 / Missing Reference 0**。18 个设计源快照与源文件及清单哈希一致；92 个用户 App UI 文件全部有映射，未发现缺失参考图片或验收证据文件。此处为映射完整性检查，不将工作台文件纳入用户 App 完成数。

历史字段 `reviewed_source_sha256` 并非统一对 `design.file` 整文件取哈希：例如导航对应 me-agent.css，妈妈首页对应 MeOverview.tsx，宝宝首页对应 baby.css，登录对应用户确认图片。因此不能将不同哈希直接认定为设计过期，也不能直接用 UserApp.tsx 的哈希覆盖历史审核记录。本次保留历史值，将匹配到的来源和未解析的历史值列为信息项；当前快照、页面定位、参考图片和验收证据分别检查。

More 页已有六项三宽/2x 跳转测试和实际原生截图，但页面映射遗漏了证据链接。重新查看 MorePage 原稿、账号卡及菜单 CSS、实际实现、参考图和原生图后补上链接。账号卡沿用原稿；账号设置、通知、专家支持和退出入口按统一菜单规范衍生，保留真实功能。此次未改变 More 页实现。

## 未关闭的业务差异

五项继续保留 Need Review：

- `profile/privacy`、`services/state-50`：缺少设计中 App 服务全局授权及对应恢复流程的契约；现有接口按具体服务保存授权。
- `services/room`：缺少将已发布咨询总结交给 Cozymate 的上下文及授权协议。等待、失败和离开恢复等已实现状态的验收不等于该交接已完成。
- `services/self-management`：设计的“保存下一步”没有实际业务处理或可确认接口。
- `services/referral`：设计的提交仅改变演示本地状态，缺少真实转介提交接口。

这些缺口此前已询问，仍待接口或业务方案；不以演示成功提示替代真实保存、授权或转介。不将五项标记为完成。
