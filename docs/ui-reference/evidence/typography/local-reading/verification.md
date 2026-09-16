# 通知与账号局部正文复核

2026-09-12。重新读取账号、通知收件箱、通知设置的衍生设计，以及设计工程 `src/styles.css` 和生活陪伴型 Design System。设计明确正文行高 1.55–1.7；普通段落基准为 1.55。

## 调整

通知正文此前显式使用 1.35；账号反馈、账号删除说明、通知设置的营销说明与权限恢复说明使用 1.5。现在这些阅读段落合并 `MomCozyTextRoles.paragraphOf(context)`，在用户主题下采用 1.55。保留字号、颜色、标题、日期、开关状态标签与操作控件样式。

原有行高保留为未注册主题扩展时的回退值，不代表用户 App 仍使用旧行高。未修改工作台主题或工作台专属页面，也未改变接口、默认通知偏好、权限及账号操作。

## 证据

- `before.log`：增加实际 RenderParagraph 断言后，通知 1.35、账号 1.5 与目标 1.55 的差异被测试复现。
- `golden-differences.log`、`settings-differences.log`：修改后原金图的预期差异。
- `golden-update.log`、`settings-golden-update.log`：仅更新相关状态基线。`golden-changes.json` 列出 21 张变更图，其余基线 SHA-256 保持不变。
- `regression.log`：最终正常模式 96 项回归通过，覆盖账号、认证、通知、公共段落角色及共享反馈；包含 320/390/430、1x/2x、短屏键盘、读取/失败/重试/已读/归档、通知同意取消、账号关联密码弹窗和删除取消。
- `analyze.log`：三个实现、两个组件测试和一个集成测试文件静态检查通过。
- `native.log`：Android 1x/2x 通过。实际检查通知正文、标记已读、归档、返回，设置说明、刷新与不请求权限，以及账号删除说明、打开确认后取消且无 mutation。
- 8 张 `native-reading-*.png` 为实际 Android 渲染。已目视检查双倍字号通知正文、设置说明及账号删除说明；内容不截断，操作可滚动到达。
- 三组 `masterImage` / `testImage` 保留调整前后的组件截图，配合衍生规范追踪差异。

Native 的通知和账号使用内存仓储，未向真实账号发送删除或通知请求；这些证据不代表 Google、推送或外部服务联调成功。

## 清单边界

三个页面原有 Completed 状态保留，补充本轮排版和行为证据。`common/theme` 中通知与账号段落子项完成，但全局局部样式汇总仍待复核，因此总数保持 147 / Completed 138 / Need Review 9 / Missing Reference 0。

普通 local APK 已成功构建并覆盖安装（`build.log`、`install.log`）；冷启动并等待资料加载后，`native-restored-home.xml` 确认回到 Mia 的 Me 页面，截图同步归档。
