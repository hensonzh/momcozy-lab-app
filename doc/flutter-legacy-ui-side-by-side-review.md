# Flutter / 旧 Web UI Side-by-side 评审

> 状态：评审记录 v0.1  
> 日期：2026-07-03  
> 旧 Web reference：`test/screenshots/legacy_web/compact_390x844/`  
> Flutter golden：`flutter_app/test/goldens/feature_pages/`、`flutter_app/test/goldens/agent_hub/`  
> 视口：390x844  

---

## 1. 结论

当前 Flutter 390x844 主路径已经接近旧 Web 的整体结构和视觉语言，但还不能判定为“完全一致”。

本轮 side-by-side 评审结论：

| 类别 | 数量 | 页面 |
|---|---:|---|
| 结构通过 | 11 | Agent Hub、Schedule、Device、Device Manage、Device User、W1、Hospital Bag、IBCLC、Media Viewer、Community、Not Found |
| 需修正 | 3 | Calibration、Records、Status |
| 需深状态补图后复核 | 2 | Pump、Agent Hub rich states |

最重要的待修正项：

1. Calibration 顶部缺少旧 Web 右上 `1/7` 步数文本。
2. Records 图表轴标、右侧区间标签和记录行操作与旧 Web 不完全一致。
3. Status 母乳趋势日期刻度与旧 Web reference 有轻微差异。

---

## 2. 评审规则

本记录不做像素级 diff，而是按以下维度评审：

- 信息架构：入口、模块顺序、页面归属是否一致。
- 首屏结构：标题、卡片、底栏、专注流程、主要 CTA 是否一致。
- 可见控件：旧 Web 首屏可见按钮、价格、删除、步数、badge 是否保留。
- 移动适配：390x844 下不裁切、不露半张卡、不缺底栏 tab。
- 文案和数据：主文案、日期、数量、单位是否明显漂移。

---

## 3. 页面矩阵

| 页面 | 旧 Web | Flutter | 结论 | 记录 |
|---|---|---|---|---|
| Agent Hub `/` | ![](../test/screenshots/legacy_web/compact_390x844/agent_hub.png) | ![](../flutter_app/test/goldens/feature_pages/agent_hub_mobile.png) | 结构通过 | 首屏问候、输入栏、右上图标、底栏结构一致；图标细节和输入栏高度有轻微 Flutter 差异，可暂不阻断。 |
| Status `/status` | ![](../test/screenshots/legacy_web/compact_390x844/status.png) | ![](../flutter_app/test/goldens/feature_pages/status_page_mobile.png) | 需修正 | 主结构一致；母乳趋势 x 轴日期范围与 reference 有轻微不一致，需要统一 fixture 或刻度算法。 |
| Schedule `/schedule` | ![](../test/screenshots/legacy_web/compact_390x844/schedule.png) | ![](../flutter_app/test/goldens/feature_pages/schedule_page_mobile.png) | 结构通过 | 月份、日期条、计划卡、Agent 提醒卡、空态、底栏结构一致；Flutter 今日任务工具按钮略贴底，需要后续深状态复核。 |
| Device `/device` | ![](../test/screenshots/legacy_web/compact_390x844/device.png) | ![](../flutter_app/test/goldens/feature_pages/device_page_mobile.png) | 结构通过 | 标题、加号、W1 横幅、Air One、左右设备卡和底栏一致。 |
| Device Manage `/device/manage` | ![](../test/screenshots/legacy_web/compact_390x844/device_manage.png) | ![](../flutter_app/test/goldens/feature_pages/device_manage_page_mobile.png) | 结构通过 | 子页结构可接受；后续需补加载/失败状态 golden。 |
| Device User `/device/user` | ![](../test/screenshots/legacy_web/compact_390x844/device_user.png) | ![](../flutter_app/test/goldens/feature_pages/device_user_page_mobile.png) | 结构通过 | 表单结构可接受；后续需补选择展开和保存失败状态 golden。 |
| W1 `/w1` | ![](../test/screenshots/legacy_web/compact_390x844/w1.png) | ![](../flutter_app/test/goldens/feature_pages/w1_page_mobile.png) | 结构通过 | 首屏产品页结构、主色和内容密度接近；营销素材文案需产品最终确认。 |
| Hospital Bag `/hospital-bag-cart` | ![](../test/screenshots/legacy_web/compact_390x844/hospital_bag_cart.png) | ![](../flutter_app/test/goldens/feature_pages/hospital_bag_page_mobile.png) | 结构通过 | Flutter 已恢复分组数量、列表行价格和删除按钮，底部结算栏保持一致。 |
| IBCLC `/ibclc-chat.html` | ![](../test/screenshots/legacy_web/compact_390x844/ibclc_chat.png) | ![](../flutter_app/test/goldens/feature_pages/ibclc_page_mobile.png) | 结构通过 | 首屏咨询入口结构接近；会话中、排队、结束状态仍需 deep-state golden。 |
| Media Viewer `/media-viewer` | ![](../test/screenshots/legacy_web/compact_390x844/media_viewer.png) | ![](../flutter_app/test/goldens/feature_pages/media_viewer_page_mobile.png) | 结构通过 | 缺资源状态一致；PDF/image/video 实际资源状态仍需 deep-state golden。 |
| Pump `/pump` | ![](../test/screenshots/legacy_web/compact_390x844/pump.png) | ![](../flutter_app/test/goldens/feature_pages/pump_page_mobile.png) | 需深状态补图后复核 | 首次校准弹窗结构一致；背景内容、模糊强度和运行/暂停/结束状态仍需补图后复核。 |
| Calibration `/calibration` | ![](../test/screenshots/legacy_web/compact_390x844/calibration.png) | ![](../flutter_app/test/goldens/feature_pages/calibration_page_mobile.png) | 需修正 | 主卡片、进度条和 CTA 已对齐；Flutter 顶部缺旧 Web 右上 `1/7` 步数文本。360 窄屏裁切已修复。 |
| Records `/records` | ![](../test/screenshots/legacy_web/compact_390x844/records.png) | ![](../flutter_app/test/goldens/feature_pages/records_page_mobile.png) | 需修正 | 页面结构一致；图表右侧区间标签、y 轴/单位切换、记录行徽标与编辑/删除操作仍有差异。 |
| Community `/community` | ![](../test/screenshots/legacy_web/compact_390x844/community.png) | ![](../flutter_app/test/goldens/feature_pages/community_page_mobile.png) | 结构通过 | 建设中空态结构一致。 |
| Not Found `*` | ![](../test/screenshots/legacy_web/compact_390x844/not_found.png) | ![](../flutter_app/test/goldens/feature_pages/not_found_page_mobile.png) | 结构通过 | 404 fallback 可接受。 |

---

## 4. 修正任务清单

### P1

| ID | 页面 | 问题 | 验收方式 |
|---|---|---|---|
| UI-P1-002 | Calibration | 顶部缺少 `1/7` 步数文本。 | Flutter calibration 三个视口 golden 顶部右侧显示当前步数/总步数。 |
| UI-P1-003 | Records | 图表区间标签、单位切换、记录行操作与旧 Web 不一致。 | Flutter records 三个视口 golden 与旧 Web reference 的图表和列表行控件一致；如保留显式编辑/删除，需产品确认。 |

### P2

| ID | 页面 | 问题 | 验收方式 |
|---|---|---|---|
| UI-P2-001 | Status | 母乳趋势日期刻度与旧 Web reference 轻微不一致。 | 统一 reference fixture 或刻度算法，golden 不再漂移。 |
| UI-P2-002 | Agent Hub | 输入栏高度、图标样式与旧 Web 有轻微差异。 | 设计确认可接受，或调整后更新 golden。 |
| UI-P2-003 | Pump | 背景模糊强度和深状态仍未完全评审。 | 增加 running、paused、finished、upload failed golden 后复核。 |

---

## 5. 下一步

优先按 P1 修正：

1. Calibration 恢复右上步数文本。
2. Records 对齐图表和行操作。

每完成一项都需要：

- 更新 Flutter 360x800、390x844、430x932 golden。
- 运行 `flutter analyze`。
- 运行 `flutter test`。
- 单独提交。
