# 当前预约业务拒绝、过期与取消恢复

通过正式 App 的 More → Me → 已购计划 → 预约咨询进入，并实际填写预约前确认。使用正式 GoRouter、BookingPage、BookingController、BookingSelectionDialog、AppointmentCancelDialog 与对应 Repository / codec；仅会话、HTTP 与时钟使用隔离依赖。未向真实账号写入预约或发送通知。

393 px / 1x 与 320 px / 2x 各执行四条操作链，共 8 项严格采集测试。上一目标轮完成测试与采集，本轮完成全宽视觉审阅、像素及源码审计和报告，属于持续推进；完整目标仍为 **NOT_PROVEN**。

## 实际操作链

| 入口与动作 | 实际结果及断言 |
| --- | --- |
| 点击可用时段，HTTP 409 | 依次覆盖 slot_unavailable、region_unavailable、service_not_bookable、appointment_exists、hold_expired、eligibility_required；显示各自业务提示，没有创建预约，也不显示暂时性错误的“重试上次提交” |
| 资格过期 → 开始确认 | 重新打开确认表，原地区、适用性和风险选择保留；继续提交成功恢复时段列表 |
| 业务拒绝后再次选择 | 保留成功 → 重新选择 → 取消 held 成功 → 返回首页 |
| 保留十分钟 → 注入时钟经过十一分钟 | 正式定时器刷新为保留到期，确认按钮消失；重新选择回到时段列表，验证未发送取消请求 |
| 新保留 → 确认被 hold_expired 拒绝 | 显示服务端拒绝；点击查询最新预约得到 expired；重新选择后允许新保留 |
| 新保留 → 确认遇 version_conflict | 点击查询最新预约，接口返回 confirmed / version 2；弹窗出现“预约已确认”与继续填写信息采集表 |
| 同步确认 → 继续填写 | 进入正式信息采集页 → 未修改直接返回已确认详情 → 返回 Me |
| 已确认 → 取消预约 → 保留预约 | 关闭弹窗，已确认预约保留 |
| 重开取消 → 确认取消 | 请求等待时按钮与关闭禁用，框架返回不能关闭；HTTP 503 后出现未知结果提示与重试／核对入口 |
| 核对预约状态 | 等待 → HTTP 503 → 仍未知 → 再核对返回 in_progress；确认取消禁用，返回预约刷新为咨询中详情，再回首页 |
| 独立已确认预约 → 取消 503 → 重试取消 | 重试保持原 expected_version 请求体；返回 cancelled，自动回 Me。独立于咨询中链，不将进行中状态人为倒退为 confirmed |

这些场景实际点击正式控件，状态由 HTTP 边界及当前产品逻辑产生。HTTP 响应变化属于隔离服务模拟，不代表生产服务或真实时段交易已执行。

## 视觉结果与当前问题

43 个状态、86 份窗口、59 张完整长图；17 个状态以完整长图作为主图，共 145 张 PNG。所有图片按全宽连续覆盖为 334 段，149 个唯一片段：109 个新增片段组成 19 张审阅页并逐张检查，40 个复用已审阅且像素完全相同的片段。审计验证每个原图哈希、从顶到底的连续覆盖及审阅页对应像素。

- 窄屏大字取消弹窗内可滚动，长图完整覆盖预约身份、说明、错误、核对和末尾按钮；等待期间按钮禁用。
- 本地时钟到期会移除确认按钮；仅服务端返回 hold_expired 时，本地 held 尚未到期，弹窗仍显示十分钟倒计时与确认按钮。查询 expired 后才移除确认，并出现两块相同的过期提示。
- version_conflict 在弹窗内显示“暂时无法确认预约，请检查网络后重试”，背景页显示记录已更新。查询得到 confirmed 后，旧错误仍与“预约已确认”同时存在；返回信息采集后背景冲突提示也仍保留。均保留当前真实输出，未修改产品来使截图看似正常。
- 取消核对得到 in_progress 时弹窗说明当前不能取消，背景在关闭并刷新前仍显示旧的已确认详情。返回后实际页面已更新。
- 320 px / 2x 首页的“进入咨询”和“填写信息”按钮仍有灰字低对比，底栏文字缩略沿用当前布局，记录为已有视觉问题。

[全宽审阅映射](booking-recovery-current-visual-review/sources.json) · [像素、源码和前驱审计](booking-recovery-current-evidence-audit.json) · [采集源码快照](booking-recovery-current-capture-source-snapshot.json)。

## 逐状态入口与图片

| 实际操作 | 图片与运行来源 |
| --- | --- |
| Select time again → fresh hold | [状态证据](../08-expert-service/booking-recovery-current-after-timeout-held/README.md) |
| After rejected attempts → hold accepted | [状态证据](../08-expert-service/booking-recovery-current-business-held/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-recovery-current-business-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-recovery-current-business-home-return/README.md) |
| Reselect accepted held time → cancellation succeeds and picker restored | [状态证据](../08-expert-service/booking-recovery-current-business-released/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-recovery-current-business-slots/README.md) |
| Retry cancellation accepted → automatic return to Me | [状态证据](../08-expert-service/booking-recovery-current-cancel-complete-home/README.md) |
| Confirm → intake → Back to confirmed detail | [状态证据](../08-expert-service/booking-recovery-current-cancel-confirmed/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-recovery-current-cancel-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-recovery-current-cancel-in-progress-home-return/README.md) |
| Return → refreshed in-progress appointment detail | [状态证据](../08-expert-service/booking-recovery-current-cancel-in-progress-return/README.md) |
| Query latest in_progress → cannot cancel, return action | [状态证据](../08-expert-service/booking-recovery-current-cancel-no-longer-allowed/README.md) |
| Cancel appointment → confirmation dialog | [状态证据](../08-expert-service/booking-recovery-current-cancel-open/README.md) |
| Confirm cancellation → request pending and dismissal disabled | [状态证据](../08-expert-service/booking-recovery-current-cancel-pending/README.md) |
| Query HTTP 503 → uncertainty retained | [状态证据](../08-expert-service/booking-recovery-current-cancel-query-error/README.md) |
| Query latest appointment → pending | [状态证据](../08-expert-service/booking-recovery-current-cancel-query-pending/README.md) |
| Keep appointment → confirmed detail | [状态证据](../08-expert-service/booking-recovery-current-cancel-retained/README.md) |
| Cancellation HTTP 503 → retry original operation | [状态证据](../08-expert-service/booking-recovery-current-cancel-retry-error/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-recovery-current-cancel-retry-home/README.md) |
| Confirmed appointment → cancellation dialog | [状态证据](../08-expert-service/booking-recovery-current-cancel-retry-open/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-recovery-current-cancel-retry-slots/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-recovery-current-cancel-slots/README.md) |
| Cancellation HTTP 503 → uncertain, retry or query latest | [状态证据](../08-expert-service/booking-recovery-current-cancel-uncertain/README.md) |
| Confirm rejected with hold_expired → query latest action | [状态证据](../08-expert-service/booking-recovery-current-confirm-hold-expired/README.md) |
| New hold confirmation HTTP 409 → query latest state | [状态证据](../08-expert-service/booking-recovery-current-confirm-version-conflict/README.md) |
| Expired precheck → Start confirmation with prior choices retained | [状态证据](../08-expert-service/booking-recovery-current-eligibility-reopened/README.md) |
| Recheck succeeds → time picker recovered | [状态证据](../08-expert-service/booking-recovery-current-eligibility-restored/README.md) |
| Hold accepted → ten-minute review | [状态证据](../08-expert-service/booking-recovery-current-expiry-held/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-recovery-current-expiry-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-recovery-current-expiry-home-return/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-recovery-current-expiry-slots/README.md) |
| Select time → HTTP 409 business rejection: appointment_exists | [状态证据](../08-expert-service/booking-recovery-current-hold-appointment_exists/README.md) |
| Select time → HTTP 409 business rejection: eligibility_required | [状态证据](../08-expert-service/booking-recovery-current-hold-eligibility_required/README.md) |
| Select time → HTTP 409 business rejection: hold_expired | [状态证据](../08-expert-service/booking-recovery-current-hold-hold_expired/README.md) |
| Select time → HTTP 409 business rejection: region_unavailable | [状态证据](../08-expert-service/booking-recovery-current-hold-region_unavailable/README.md) |
| Select time → HTTP 409 business rejection: service_not_bookable | [状态证据](../08-expert-service/booking-recovery-current-hold-service_not_bookable/README.md) |
| Select time → HTTP 409 business rejection: slot_unavailable | [状态证据](../08-expert-service/booking-recovery-current-hold-slot_unavailable/README.md) |
| Injected device clock passes hold expiry → reselect notice | [状态证据](../08-expert-service/booking-recovery-current-hold-timeout/README.md) |
| Query latest reveals confirmed → continue intake action | [状态证据](../08-expert-service/booking-recovery-current-latest-confirmed/README.md) |
| Continue from synchronized confirmation → intake | [状态证据](../08-expert-service/booking-recovery-current-latest-confirmed-intake/README.md) |
| Unchanged intake Back → confirmed appointment | [状态证据](../08-expert-service/booking-recovery-current-latest-confirmed-return/README.md) |
| Query latest returns expired → reselect remains | [状态证据](../08-expert-service/booking-recovery-current-latest-expired/README.md) |
| Reselect elapsed hold → picker without cancel mutation | [状态证据](../08-expert-service/booking-recovery-current-timeout-reselected/README.md) |

## 验证与剩余范围

8 项严格采集通过，未更新 Golden；实际代码与测试目录静态检查通过。源码快照与当前相关代码一致。图像和引用完整性检查只证明本批资产可追溯，不证明全 App 已盘点完成。

- [严格采集日志](runs/20260914T024003-targeted/capture.log)
- [静态检查](booking-recovery-current-analyze.log)
- [资产完整性检查](booking-recovery-current-final-verify.log)

结合 [预约前确认](BOOKING-PRECHECK-CURRENT.md)、[选择与确认](BOOKING-SELECTION-CURRENT.md)，已补齐以上冲突、过期、查询和取消分支。未决操作关闭后重新进入、提醒实际启用及失败、信息采集内部提交、咨询与总结内部链路，以及服务模块其他未核对条件仍须继续。单个批次通过不替代整个目标的完成审计。
