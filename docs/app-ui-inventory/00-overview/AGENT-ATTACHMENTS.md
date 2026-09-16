# Cozymate 附件实际交互链

新增 **47 个正常路径状态、64 个尺寸/字号变体**。393 px 下本批状态均可一屏展示；320 px、2x 字号有 **13 张完整纵向长图**。8 条实际交互测试通过，不把这些状态数量当作独立页面数量或整体覆盖率。

## 已执行的操作

- More → Cozymate → 附件菜单 → 相机/照片/文件：选择等待时输入区锁定，取消后恢复原草稿；相机和文件选择失败显示反馈。
- 图片上传 50% → 上传成功 → 切换 More 再返回：附件和文字草稿保持。删除请求等待 → 503 失败保留附件与草稿 → 下滑关闭提示 → 再次删除成功；重试使用同一幂等键。
- 相机图片 + PDF：横向滚动附件条分别查看 → 发送文字和两个附件 ID → 回复完成 → 点击已发图片 → 全屏 → 双指缩放 → 平移 → 返回。393/1x 与 320/2x 均实际操作。
- PDF 选择：非 PDF 内容被真实校验器拒绝，超过 10 MB 显示限制，空文件不上传；有效文件上传失败 → 关闭提示 → 重新选择并上传成功 → 仅文件发送 → 完成。
- 新建会话：草稿附件清理失败保留当前草稿 → 关闭提示 → 再次新建、等待删除 → 成功后清空附件与文字。
- 图片上传失败 → 再选本地损坏图片 → 缩略图解码兜底 → 仅图片发送 → 全屏加载错误 → 远程原图请求失败 → 点击重试、加载中 → 原图恢复 → 返回原消息。
- 已发送 PDF 元数据卡实际点击后保持当前对话，没有打开预览。该卡当前无预览回调，不能把媒体模块独立 PDF 预览当作此入口的后续页面。

## 依赖与真实性边界

测试沿正式 `MomCozyFlutterApp/createMomCozyRouter/AgentHubPage` 的公共构造入口运行，实际点击按钮、拖动附件条、输入、发送及操作图片查看器。保留正式 SSE parser、runner 默认重试策略、media Repository、上传/删除请求构造、图片 codec 与 PDF 内容/大小校验。

隔离边界是 picker 返回值、HTTP/SSE 字节、资料、会话存储与语音播放器。本轮没有调用远程模型、提交真实账号数据或操作原生设备。系统照片/PDF 选择器、相机首次授权及取消的已有原生证据见 [系统步骤](../native/agent/README.md)，不能用本轮注入 picker 的截图代替系统选择成功证明。

图片解码失败场景直接在 picker 边界注入 8 字节 PNG 签名，再模拟服务端成功接受；用于观察客户端损坏缩略图与原图重试，不声称系统 picker 或真实后端会接受该文件。远程恢复返回仓库中的普通水滴图片。PDF fixture、图片、英文消息均为隔离测试数据。

## 视觉发现与采集修正

1. 上传/删除失败 Snackbar 浮在输入区上，会遮住附件按钮。测试先实际下滑关闭提示，再点击附件按钮重试；没有通过绕过命中测试点击被遮挡控件。
2. 已发送 PDF 卡只展示文件名与体积。未创建不存在的预览页面或虚假的跳转证明。
3. 小屏、大字号下，输入区多行、导航换行，附件名省略；已沿滚动区采集全部对话正文。单条附件横向裁切属于可滚动条，在两个横向位置各有截图。
4. 首次视觉复查发现“回到最新消息”浮层被重复拼进长图，留下黑边。采集器现在每次滚动后重新测量底部浮层，并按实际高度保留重叠区域，排除 `Positioned.fill` 的全幅装饰。13 张附件长图已逐段检查，重复黑边消除；普通窗口仍保留真实浮层。
5. 固定背景渐变仍可能在分屏拼接处出现色块接缝，不能据此判定产品静态设计有同样接缝。长图用于完整内容盘点，原窗口用于判断浮层和页面真实布局。

## 逐状态入口

每个状态 README 记录正常入口、实际路由、触发、前驱、原窗口、长图及源码。部分取消/点击无动作的状态外观相同，但保留了验证该动作结果的步骤证据。

| 状态 | 路由 | 操作 | 证据 |
| --- | --- | --- | --- |
| camera-failure-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-camera-failure-dismissed/README.md) |
| camera-pick-cancelled | `/` | Cancel camera selection → unchanged draft, no upload | [状态](../05-agent/agent-attachment-journey-camera-pick-cancelled/README.md) |
| camera-pick-failed | `/` | Camera picker reports failure → image upload failure snackbar | [状态](../05-agent/agent-attachment-journey-camera-pick-failed/README.md) |
| camera-pick-pending | `/` | Open camera picker boundary → input locked while result pending; not an OS screenshot | [状态](../05-agent/agent-attachment-journey-camera-pick-pending/README.md) |
| file-pick-cancelled | `/` | Cancel file selection → unchanged draft, no upload | [状态](../05-agent/agent-attachment-journey-file-pick-cancelled/README.md) |
| file-pick-failed | `/` | Document picker reports failure → file upload failure snackbar | [状态](../05-agent/agent-attachment-journey-file-pick-failed/README.md) |
| file-pick-pending | `/` | Open file picker boundary → input locked while result pending; not an OS screenshot | [状态](../05-agent/agent-attachment-journey-file-pick-pending/README.md) |
| image-decode-fallback | `/` | Uploaded image cannot decode locally → fallback thumbnail | [状态](../05-agent/agent-attachment-journey-image-decode-fallback/README.md) |
| image-panned | `/` | Drag enlarged image → panned view | [状态](../05-agent/agent-attachment-journey-image-panned/README.md) |
| image-ready | `/` | Upload succeeds → removable local image preview | [状态](../05-agent/agent-attachment-journey-image-ready/README.md) |
| image-remote-failed | `/` | Reload original via authenticated content repository → HTTP error | [状态](../05-agent/agent-attachment-journey-image-remote-failed/README.md) |
| image-remote-loading | `/` | Retry original image → loading indicator | [状态](../05-agent/agent-attachment-journey-image-remote-loading/README.md) |
| image-remote-recovered | `/` | Valid remote original received → image available | [状态](../05-agent/agent-attachment-journey-image-remote-recovered/README.md) |
| image-remote-return | `/` | Return after remote recovery → original transcript | [状态](../05-agent/agent-attachment-journey-image-remote-return/README.md) |
| image-remove-failed | `/` | Deletion fails → image and draft retained with snackbar | [状态](../05-agent/agent-attachment-journey-image-remove-failed/README.md) |
| image-remove-notice-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-image-remove-notice-dismissed/README.md) |
| image-remove-pending | `/` | Remove image → deletion pending and input locked | [状态](../05-agent/agent-attachment-journey-image-remove-pending/README.md) |
| image-removed | `/` | Remove again → same idempotency key, image deleted, text draft preserved | [状态](../05-agent/agent-attachment-journey-image-removed/README.md) |
| image-tab-away | `/more` | More tab with unsent image and text draft | [状态](../05-agent/agent-attachment-journey-image-tab-away/README.md) |
| image-tab-return | `/` | Return to Cozymate → unsent image and draft retained | [状态](../05-agent/agent-attachment-journey-image-tab-return/README.md) |
| image-upload-failed | `/` | Image upload HTTP 503 → no attachment and retry feedback | [状态](../05-agent/agent-attachment-journey-image-upload-failed/README.md) |
| image-upload-failure-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-image-upload-failure-dismissed/README.md) |
| image-uploading | `/` | Photo result → multipart upload at 50%, composer locked | [状态](../05-agent/agent-attachment-journey-image-uploading/README.md) |
| image-viewer | `/` | Tap sent image → full-screen local image | [状态](../05-agent/agent-attachment-journey-image-viewer/README.md) |
| image-viewer-error | `/` | Open corrupt local image → full-screen error with remote reload | [状态](../05-agent/agent-attachment-journey-image-viewer-error/README.md) |
| image-viewer-return | `/` | Viewer return button → same conversation | [状态](../05-agent/agent-attachment-journey-image-viewer-return/README.md) |
| image-zoomed | `/` | Two-finger pinch → enlarged image | [状态](../05-agent/agent-attachment-journey-image-zoomed/README.md) |
| mixed-completed | `/` | Reply completes → sent image and PDF metadata in transcript | [状态](../05-agent/agent-attachment-journey-mixed-completed/README.md) |
| mixed-ready-file | `/` | Scroll attachment strip → PDF and removal control visible | [状态](../05-agent/agent-attachment-journey-mixed-ready-file/README.md) |
| mixed-ready-image | `/` | Camera result and PDF selected → both uploaded in composer | [状态](../05-agent/agent-attachment-journey-mixed-ready-image/README.md) |
| mixed-sent | `/` | Send text and two uploaded file IDs → waiting response | [状态](../05-agent/agent-attachment-journey-mixed-sent/README.md) |
| new-cleanup-completed | `/` | Cleanup succeeds → new conversation, no abandoned file or text draft | [状态](../05-agent/agent-attachment-journey-new-cleanup-completed/README.md) |
| new-cleanup-failed | `/` | New conversation → server cleanup failure retains PDF and draft | [状态](../05-agent/agent-attachment-journey-new-cleanup-failed/README.md) |
| new-cleanup-notice-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-new-cleanup-notice-dismissed/README.md) |
| new-cleanup-pending | `/` | Retry new conversation → deletion pending and controls disabled | [状态](../05-agent/agent-attachment-journey-new-cleanup-pending/README.md) |
| pdf-empty | `/` | Real document picker validates empty selected bytes before upload | [状态](../05-agent/agent-attachment-journey-pdf-empty/README.md) |
| pdf-metadata-tapped | `/` | Tap sent PDF metadata → current page has no PDF preview action | [状态](../05-agent/agent-attachment-journey-pdf-metadata-tapped/README.md) |
| pdf-only-completed | `/` | Send without text → default file prompt and final reply | [状态](../05-agent/agent-attachment-journey-pdf-only-completed/README.md) |
| pdf-oversized | `/` | Real document picker validates oversized selected bytes before upload | [状态](../05-agent/agent-attachment-journey-pdf-oversized/README.md) |
| pdf-oversized-notice-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-pdf-oversized-notice-dismissed/README.md) |
| pdf-unsupported | `/` | Real document picker validates unsupported selected bytes before upload | [状态](../05-agent/agent-attachment-journey-pdf-unsupported/README.md) |
| pdf-unsupported-notice-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-pdf-unsupported-notice-dismissed/README.md) |
| pdf-upload-failed | `/` | Valid PDF upload HTTP 503 → feedback and no pending file | [状态](../05-agent/agent-attachment-journey-pdf-upload-failed/README.md) |
| pdf-upload-failure-dismissed | `/` | Swipe failure snackbar away → attachment controls visible again | [状态](../05-agent/agent-attachment-journey-pdf-upload-failure-dismissed/README.md) |
| pdf-upload-recovered | `/` | Select PDF again → successful upload | [状态](../05-agent/agent-attachment-journey-pdf-upload-recovered/README.md) |
| photo-pick-cancelled | `/` | Cancel photo selection → unchanged draft, no upload | [状态](../05-agent/agent-attachment-journey-photo-pick-cancelled/README.md) |
| photo-pick-pending | `/` | Open photo picker boundary → input locked while result pending; not an OS screenshot | [状态](../05-agent/agent-attachment-journey-photo-pick-pending/README.md) |

## 执行与审阅证据

- 附件专项：8 项通过；第一次严格采集见 [专项日志](runs/20260913T130851-targeted/capture.log)。修正通用采集器后已完整重采 **77 个视觉测试文件，987 项通过、6 项既有跳过、0 失败**，59 秒，见 [最终全量日志](capture.log) 与 [结果](capture-result.json)。这里“全量”仅指视觉测试集合，不是所有单元测试。
- 全仓 `flutter analyze --no-pub` 无问题，见 [静态检查](agent-attachments-analyze.log)。两个附件测试文件及采集器格式检查 0 changed。
- 47 张主窗口通过四张总览审阅；320/2x 的 17 张窗口与 13 张长图切成 43 段，六张审阅图全部查看。来源与哈希见 [主窗口清单](agent-attachment-visual-review/overview-sources.json) 和 [大字号分段清单](agent-attachment-visual-review/narrow-sources.json)。
- 修改全局采集器后已重采其他模块；早期报告附带的审阅总览属于当时版本，不能自动视为本次全部长图重新人工审核。当前只确认附件本批长图及修正涉及的抽查；全体长图审核仍待完成。
- 当前完整性校验 PASS：965 条目、2033 个变体、730 个长图测量、589 个正常路由状态。校验仅证明文件、哈希、链接、路由记录和滚动范围一致。

## 仍需完成

Cozymate 的奶量分析/恢复评估、artifact 业务跳转、表单及 action 确认、支持工单、语音播放/麦克风、条件历史入口仍缺完整正常路径链；“回到最新消息”按钮已观察到，实际点击后的状态尚待补。附件数量上限、混合附件部分清理失败、失效或无权访问文件及真实系统选取成功仍未覆盖。其它模块剩余分支、系统权限层、无正常入口代码最终清单和全部长图审核仍需推进。


后续已补两个业务快捷入口、通用表单/工单提交、动作确认与“回到最新消息”的实际点击，见 [AGENT-WORKFLOWS.md](AGENT-WORKFLOWS.md)。本报告总量为当时记录。
