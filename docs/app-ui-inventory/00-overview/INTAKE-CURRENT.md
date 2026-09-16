# G09：信息采集表、说明与完成浮层归并

本项完成：原清单已有信息使用说明和保存成功的真实路径图；本轮修正两个浮层遗漏的组件归属，并复用当前 1 个既有场景的 5 张状态图，补全其中 3 张表单长图。没有新增测试或尺寸组合。

## 入口与去向

预约确认 → 信息采集表 → 咨询重点／补充情况／基础信息 → 信息使用“查看说明” → 知道了 → 勾选授权 → 保存 → 信息采集已完成。

- “稍后再说，查看预约”回到已确认预约，沿用 [实际入口证据](../08-expert-service/service-journey-intake-saved-return/README.md)。
- “开始预问诊”进入 Cozymate 预填对话、未自动发送，沿用 [服务操作链](SERVICE-JOURNEYS.md)。本次单页场景实际点击此按钮并断言返回保存版本，不将回调升级成新的路由证据。
- 更新已有表单直接返回；首次保存才出现完成选择。保留原行为及历史路径，不重复截图返回后的同一预约或首页。

## 当前完整图

| 状态 | 完整图 | 核对范围 |
| --- | --- | --- |
| 信息使用说明 | [图](../raw/test/goldens/design_system/intake-consent-390.png) · [索引](../08-expert-service/intake-consent/README.md) | 提供给谁、包含什么、用于什么、关闭及知道了 |
| 表单与授权未勾选 | [图](../raw/test/goldens/design_system/intake-form-390.long.png) · [索引](../08-expert-service/intake-form/README.md) | 咨询重点至信息使用和保存禁用按钮 |
| 展开补充情况 | [图](../raw/test/goldens/design_system/intake-optional-390.long.png) · [索引](../08-expert-service/intake-optional/README.md) | 补充字段及页面底部完整 |
| 展开基础信息 | [图](../raw/test/goldens/design_system/intake-profile-390.long.png) · [索引](../08-expert-service/intake-profile/README.md) | 地区、产后天数、宝宝信息、喂养方式及授权／保存完整 |
| 首次保存成功 | [图](../raw/test/goldens/design_system/intake-saved-390.png) · [索引](../08-expert-service/intake-saved/README.md) | 预约和专家摘要、开始预问诊、稍后查看预约；无额外关闭按钮 |

## 清单修正与验证

两个浮层原定义的 `widgets` 为空，导致候选数为 0，不能据此认为缺图。现在按宿主信息采集页、旧版 ProductFlowDialog／当前 MomSettingsFlowDialog 及各自独有标题共同关联；总浮层数仍为 35，不新增页面。历史图保留日期与来源，当前代表图在上表。

- [既有场景严格验证](runs/20260914T080915-intake-current/capture.log)：1 项通过，未更新金图。
- [逐图、长图范围与源码指纹](runs/20260914T080915-intake-current/g09-audit.json)：相关代码与改版 verified-files 指纹匹配，5 图均已目视检查。
- 本项关闭的是已具名说明／完成浮层和表单完整图归档。其它历史表单错误、选择器及共享状态版本仍按 G11 核对；原生键盘归 G10。没有发送真实信息或更改生产授权。
