# 用户 App 页面映射与验收进度

范围：用户 App 全部页面、嵌套流程、弹窗及状态。IBCLC 仅单独登记，不在重构范围。

此表是当前进度事实来源；2026-09-09 / 09-11 旧审计的“完成”不继承。

Total Pages / UI views: **147** · Completed: **142** · Need Review: **5** · Missing Reference: **0**

原始独立稿件缺少的 33 个条目已按用户确认建立衍生规范；原稿缺失与衍生规范覆盖不混为一谈。衍生页仍需逐项实现和验收。

计数单位是独立可验收的页面/弹窗/状态，状态不冒充独立路由。当前为首轮盘点，未映射的组件及内联弹窗见 implementation-inventory.json，必须补审后才能宣称完整。

| 设计页面 / 状态 | 当前 App 页面 | Route / 入口 | 实现盘点 | 验收状态 |
| --- | --- | --- | --- | --- |
| [五入口底部导航](common/navigation.md) | `lib/app/mom_bottom_navigation.dart` | `/me /baby / /schedule /more` | present | Completed |
| [Me 首页](mom/home.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [每日知识详情](mom/knowledge.md) | `lib/shared/widgets/knowledge_banner.dart` | `/me` | present | Completed |
| [记录入口选择](mom/record-picker.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [昨夜休息](mom/diary-rest.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [身体与精力](mom/diary-body.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日心情](mom/diary-mood.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [独立日记编辑页](mom/diary-history.md) | `lib/modules/mom/presentation/mother_diary_page.dart` | `/me/diary` | present | Completed |
| [今日泌乳与趋势](mom/lactation.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [泌乳新增和编辑](mom/lactation-edit.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [其它功能禁用入口](mom/other-functions.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [Baby 首页](baby/home.md) | `lib/modules/baby/presentation/baby_home_page.dart` | `/baby` | present | Completed |
| [切换宝宝](baby/switcher.md) | `lib/modules/baby/presentation/baby_home_page.dart` | `/baby` | present | Completed |
| [宝宝资料新增编辑](baby/profile.md) | `lib/modules/baby/presentation/baby_profile_editor.dart` | `/baby` | present | Completed |
| [睡眠记录](baby/sleep.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [尿湿记录](baby/wet.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [便便记录](baby/stool.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [喂养记录](baby/feeding.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [生长记录](baby/growth-entry.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [发展观察](baby/development.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [生长曲线](baby/growth.md) | `lib/modules/baby/presentation/baby_growth_curve.dart` | `/baby` | present | Completed |
| [宝宝历史记录](baby/records.md) | `lib/modules/baby/presentation/baby_records_page.dart` | `/babies/:babyId/records` | present | Completed |
| [宝宝每日知识详情](baby/knowledge.md) | `lib/shared/widgets/knowledge_banner.dart` | `/baby` | present | Completed |
| [Cozymate 会话](agent/home.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [会话历史](agent/history.md) | `lib/features/agent_hub/presentation/agent_conversation_panel.dart` | `/` | present | Completed |
| [附件菜单](agent/attachments.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [消息操作](agent/message-menu.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [结构化工具结果](agent/structured-card.md) | `lib/features/agent_hub/artifacts/agent_artifact_panel.dart` | `/` | present | Completed |
| [结构化表单](agent/form.md) | `lib/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart` | `/` | present | Completed |
| [对话图片与全屏预览](agent/image-preview.md) | `lib/features/agent_hub/presentation/agent_image_previews.dart` | `/` | present | Completed |
| [文件附件预览](agent/file-preview.md) | `lib/features/agent_hub/presentation/agent_file_previews.dart` | `/` | present | Completed |
| [语音操作](agent/voice.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [日程月历与当日安排](schedule/home.md) | `lib/modules/schedule/presentation/schedule_page.dart` | `/schedule` | present | Completed |
| [新增个人日程](schedule/create.md) | `lib/modules/schedule/presentation/schedule_page.dart` | `/schedule` | present | Completed |
| [编辑与删除个人日程](schedule/edit.md) | `lib/modules/schedule/presentation/schedule_page.dart` | `/schedule` | present | Completed |
| [专业任务状态菜单](schedule/task.md) | `lib/modules/schedule/presentation/schedule_page.dart` | `/schedule` | present | Completed |
| [More](profile/more.md) | `lib/modules/profile/presentation/more_page.dart` | `/more` | present | Completed |
| [信息授权管理](profile/privacy.md) | `lib/modules/profile/presentation/privacy_page.dart` | `/privacy` | present | Need Review |
| [账号管理与删除](profile/account.md) | `lib/features/auth/presentation/account_page.dart` | `/account` | present | Completed |
| [通知收件箱](profile/notifications.md) | `lib/features/notifications/presentation/notifications_page.dart` | `/notifications` | present | Completed |
| [通知设置](profile/notification-settings.md) | `lib/features/notifications/presentation/notification_settings_page.dart` | `/notifications/settings` | present | Completed |
| [专家服务列表](services/catalog.md) | `lib/modules/services/presentation/service_catalog_page.dart` | `/services` | present | Completed |
| [服务详情](services/package.md) | `lib/modules/services/presentation/service_package_page.dart` | `/services/:packageId` | present | Completed |
| [专家团队](services/team.md) | `lib/modules/services/presentation/service_catalog_page.dart` | `/services/:packageId` | present | Completed |
| [适用性和购买支付](services/purchase.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [预约专家时间](services/booking.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约详情](services/appointment.md) | `lib/modules/services/presentation/appointment_detail_page.dart` | `/services/appointments/:appointmentId` | present | Completed |
| [信息采集与授权](services/intake.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [信息使用说明](services/consent-detail.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [首次信息采集完成](services/intake-saved.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [预约与咨询准备](services/preparation.md) | `lib/modules/consultation/presentation/room_page.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [摄像头麦克风检测](services/device-check.md) | `lib/modules/consultation/presentation/device_check_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [本次服务的视频咨询授权](services/video-consent.md) | `lib/modules/consultation/presentation/consultation_start_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [视频咨询](services/room.md) | `lib/modules/consultation/presentation/room_page.dart` | `/services/appointments/:appointmentId/room` | present | Need Review |
| [暂时离开咨询室](services/room-leave.md) | `lib/modules/consultation/presentation/room_page.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询总结](services/summary.md) | `lib/modules/services/presentation/consultation_summary_page.dart` | `/services/appointments/:appointmentId/summary` | present | Completed |
| [咨询行动详情与反馈](services/summary-task.md) | `lib/modules/services/presentation/consultation_summary_page.dart` | `/services/appointments/:appointmentId/summary` | present | Completed |
| [服务进度](services/progress.md) | `lib/modules/services/presentation/service_progress_page.dart` | `/services/episodes/:episodeId` | present | Completed |
| [续购](services/renew.md) | `lib/modules/services/presentation/service_renew_page.dart` | `/services/renew /services/episodes/:episodeId/renew` | present | Completed |
| [自主管理](services/self-management.md) | `待确认/缺失` | `未实现；设计入口 /app/self-management` | missing_or_unmapped | Need Review |
| [转介](services/referral.md) | `待确认/缺失` | `未实现；设计入口 /app/referral` | missing_or_unmapped | Need Review |
| [图片与视频资料](common/media.md) | `lib/features/media/presentation/media_viewer_page.dart` | `/media-viewer` | present | Completed |
| [PDF 阅读](common/pdf.md) | `lib/features/media/presentation/media_viewer_page.dart` | `/media-viewer` | present | Completed |
| [动作评估](common/motion.md) | `lib/features/motion_assessment/presentation/motion_assessment_page.dart` | `Agent 动作入口` | present | Completed |
| [页面不存在](common/not-found.md) | `lib/app/momcozy_app.dart` | `/404` | present | Completed |
| [加载状态](common/loading.md) | `lib/shared/widgets/product_feedback.dart` | `各页面` | present | Completed |
| [公共空状态](common/empty.md) | `lib/shared/widgets/product_feedback.dart` | `各页面` | present | Completed |
| [错误与重试](common/error.md) | `lib/shared/widgets/product_feedback.dart` | `各页面` | present | Completed |
| [公共确认与丢弃](common/confirm.md) | `lib/shared/widgets/confirm_discard.dart` | `各表单` | present | Completed |
| [保存与撤销反馈](common/success.md) | `lib/modules/baby/presentation/baby_saved_feedback.dart` | `各表单` | present | Completed |
| [输入、选择与日期时间弹窗](common/input.md) | `lib/shared/widgets/choice_field.dart` | `各表单` | present | Completed |
| [全局 Theme / Design Tokens](common/theme.md) | `lib/shared/design_system/momcozy_theme.dart` | `全局` | present | Completed |
| [邮箱和 Google 登录](auth/login.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [创建账号](auth/register.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [验证邮箱](auth/verify.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [找回密码](auth/forgot.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [重置密码](auth/reset.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [语言选择](auth/language.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [条款与隐私链接](auth/legal.md) | `lib/features/auth/presentation/auth_page.dart` | `/login` | present | Completed |
| [内部邀请码入口](auth/invite.md) | `lib/features/auth/presentation/invite_auth_page.dart` | `/login (internalInviteOnly)` | present | Completed |
| [基本资料](auth/onboarding-profile.md) | `lib/features/onboarding/presentation/onboarding_page.dart` | `/onboarding` | present | Figma update pending |
| [分娩日期](auth/onboarding-delivery.md) | `lib/features/onboarding/presentation/onboarding_page.dart` | `/onboarding` | present | Figma update pending |
| [分娩资料](auth/onboarding-birth.md) | `lib/features/onboarding/presentation/onboarding_page.dart` | `/onboarding` | present | Figma update pending |
| [Me首页-空服务状态](mom/state-01.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [每日知识-详情弹窗](mom/state-02.md) | `lib/shared/widgets/knowledge_banner.dart` | `/me` | present | Completed |
| [每日知识-Cozymate去向](agent/state-03.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [今日状态-休息](mom/state-04.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-休息补充展开](mom/state-05.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-身体与精力](mom/state-06.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-身体不适条件项](mom/state-07.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-如厕与盆底展开](mom/state-08.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-心情](mom/state-09.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [今日状态-保存前校验](mom/state-10.md) | `lib/modules/mom/presentation/mother_diary_editor.dart` | `/me` | present | Completed |
| [Me首页-今日状态已记录](mom/state-11.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [今日泌乳-空记录](mom/state-12.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-新增泵奶](mom/state-13.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-新增亲喂](mom/state-14.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-补充感受与备注](mom/state-15.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-输入校验失败](mom/state-16.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-已保存记录](mom/state-17.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-编辑记录](mom/state-18.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [今日泌乳-删除后可撤销](mom/state-19.md) | `lib/modules/mom/presentation/lactation_panel.dart` | `/me /me/lactation` | present | Completed |
| [专家支持-服务方案列表](services/state-20.md) | `lib/modules/services/presentation/service_catalog_page.dart` | `/services` | present | Completed |
| [专家支持-喂养安心服务详情](services/state-21.md) | `lib/modules/services/presentation/service_package_page.dart` | `/services/:packageId` | present | Completed |
| [专家支持-亲喂改善服务详情](services/state-22.md) | `lib/modules/services/presentation/service_package_page.dart` | `/services/:packageId` | present | Completed |
| [专家支持-奶量管理服务详情](services/state-23.md) | `lib/modules/services/presentation/service_package_page.dart` | `/services/:packageId` | present | Completed |
| [专家支持-舒适哺乳支持服务详情](services/state-24.md) | `lib/modules/services/presentation/service_package_page.dart` | `/services/:packageId` | present | Completed |
| [购买流程-购买前确认](services/state-25.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [购买流程-服务州不支持](services/state-26.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [购买流程-安全支付](services/state-27.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [购买流程-付款失败](services/state-28.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [购买流程-3D-Secure验证](services/state-29.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [购买流程-购买成功](services/state-30.md) | `lib/modules/services/presentation/service_purchase_dialog.dart` | `/services/:packageId` | present | Completed |
| [Me首页-服务已购买待预约](mom/state-31.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [预约流程-预约前确认](services/state-32.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约流程-所在州不支持](services/state-33.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约流程-紧急风险提示](services/state-34.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约流程-选择日期与专家时间](services/state-35.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约流程-确认预约时间](services/state-36.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [预约确认后进入信息采集](services/state-37.md) | `lib/modules/services/presentation/booking_page.dart` | `/services/episodes/:episodeId/booking` | present | Completed |
| [Me首页-预约已确认待填表](mom/state-38.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [预约流程-信息采集表](services/state-39.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [信息采集表-补充情况展开](services/state-40.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [信息采集表-基础信息展开](services/state-41.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [信息采集表-信息使用说明](services/state-42.md) | `lib/modules/services/presentation/intake_page.dart` | `/services/appointments/:appointmentId/intake` | present | Completed |
| [Me首页-咨询准备与倒计时](mom/state-43.md) | `lib/modules/mom/presentation/mother_home_page.dart` | `/me` | present | Completed |
| [咨询准备-设备检测中](services/state-44.md) | `lib/modules/consultation/presentation/device_check_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-设备检测失败](services/state-45.md) | `lib/modules/consultation/presentation/device_check_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-设备检测通过](services/state-46.md) | `lib/modules/consultation/presentation/device_check_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-开始视频咨询](services/state-47.md) | `lib/modules/consultation/presentation/consultation_start_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-当前州不支持](services/state-48.md) | `lib/modules/consultation/presentation/consultation_start_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-视频授权已撤回](services/state-49.md) | `lib/modules/consultation/presentation/consultation_start_dialog.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [咨询准备-恢复授权去向](services/state-50.md) | `lib/modules/profile/presentation/privacy_page.dart` | `/privacy` | present | Need Review |
| [预约流程-预约详情](services/state-51.md) | `lib/modules/services/presentation/appointment_detail_page.dart` | `/services/appointments/:appointmentId` | present | Completed |
| [预约流程-取消预约确认](services/state-52.md) | `lib/modules/services/presentation/appointment_detail_page.dart` | `/services/appointments/:appointmentId` | present | Completed |
| [视频咨询-等待专家进入](services/state-53.md) | `lib/modules/consultation/presentation/room_page.dart` | `/services/appointments/:appointmentId/room` | present | Completed |
| [喂养校验错误](baby/feeding-validation.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [喂养保存撤销](baby/feeding-saved.md) | `lib/modules/baby/presentation/baby_home_page.dart` | `/baby` | present | Completed |
| [正在睡眠](baby/sleep-active.md) | `lib/modules/baby/presentation/baby_record_editor.dart` | `/baby /babies/:babyId/records` | present | Completed |
| [缺少生长资料](baby/empty-growth-320.md) | `lib/modules/baby/presentation/baby_growth_curve.dart` | `/baby` | present | Completed |
| [长昵称和短屏](baby/profile-short-viewport.md) | `lib/modules/baby/presentation/baby_profile_editor.dart` | `/baby` | present | Completed |
| [请求失败和重试](agent/12-agent-error.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |
| [对话回复](agent/12b-agent-conversation.md) | `lib/features/agent_hub/agent_hub_page.dart` | `/` | present | Completed |

## 待补盘点（不是已完成）

- 内联弹窗、动态 Agent 卡片、权限/离线/处理中、原生媒体系统界面逐项复核。
- 设计端独有功能查清为业务差异、不可用占位或缺失 UI；不得凭名称删除。
- 登录使用用户最近确认的设计，保留真实认证协议；其它没有原稿的流程单独标注。
- 滚动页面继续补长图；viewport 图只证明可见区域。
- 原始产品设计中以前的 inventory/探索图不凌驾于当前 CSS 和后续定稿。
