# 公共状态说明文字行高

依据：`source/src/styles.css` 的 `p { line-height: 1.55; }`、`UI.tsx` 的 EmptyState，以及生活陪伴型 Design System 的正文行高 1.55–1.7。加载与错误沿用用户确认的衍生规范；没有把组件验证新增为设计原稿。

## 差异与处理范围

主题的 bodyMedium 原始 height 为 null，但 Material 最终渲染的普通 Text 继承 1.43。`theme-values-before.txt` 与 `before.txt` 分别记录这两个层次；旧探针对工作台 null 的预期不正确，正式测试已改为核对实际渲染值 1.43。

新增 `MomCozyTextRoles.paragraph`，只在用户主题注册。公共空状态的说明、错误原因及保留草稿说明、加载文案采用 1.55；保持各自字号、颜色与对齐。标题、按钮、输入值不改用段落行高。工作台不注册该扩展，继续继承原有样式。没有改全局 bodyMedium 或 Dialog contentTextStyle，以免影响内部控件。

本轮不等于全 App 段落审计完成。通知列表摘要、账号局部说明及其他自定义正文仍需按各自参考逐项核对，common/theme 保持 Need Review。

## 验证范围

`test/app/reading_typography_test.dart` 检查真实 RenderParagraph：四类说明在用户主题为 1.55、工作台为 1.43，标题与普通标签不变。现有公共反馈测试覆盖 320/390/430、1x/2x、短区域滚动、live region、六类错误及恢复回调。

已查看变更前后公共错误图，以及首次使用、通知空状态、媒体加载、保存待确认、日记键盘错误、预约、采集表和咨询结束态。差异来自行距及内容高度，操作仍完整可见或能滚动到达。对应金图更新后须正常模式匹配，不能把更新模式当作最终验证。

Android 复用公共反馈组件夹具，重试、撤销和关闭只修改内存，不调用保存、删除、通知或外部服务。普通本地 App 的构建与恢复记录单独归档。

`regression.txt`：1,348 项正常模式回归通过，包含用户 App、公共组件和工作台边界检查；未启用更新金图。`golden-update.txt` 为之前 311 项截图基线更新过程，单独保留，不与最终验证混算。

`native.txt`：Android 1x/2x 公共状态与回调测试通过，六张加载、空状态、错误截图已归档。已目视检查错误双段文字、重试和空状态标题的层级与换行。`analyze.txt`：本轮四个实现及测试文件静态检查无问题。

`build.txt` 与 `install.txt`：普通 local 调试 APK 构建、覆盖安装成功。已退出测试夹具，冷启动回到 `/me`；等待资料载入后再次截图，XML 确认 Mia 已恢复，见 `native-restored-home.png` / `.xml`。未清除账号数据或更改权限。

清单结果仍为 147 / Completed 128 / Need Review 19 / Missing Reference 0；103 个用户 UI 文件均有映射。本轮只补齐公共状态排版证据，不将尚缺局部复核或真实服务验证的页面标为完成。
