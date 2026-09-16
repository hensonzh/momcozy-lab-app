# 用户咨询结束页

完成现有 8 个截图条目对应的用户结束状态。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=198-1108) 完成结果与操作层级，再实现 Flutter。[10 个设计画板](figma-nodes.json) 覆盖正常完成、待整理记录、技术故障、未能到场、转介支持、预约取消，以及双倍字号和短屏滚动。

新版使用结果卡清楚说明本次状态，随后显示原有下一步操作，再用 MomAppointmentSummary 呈现日期、时区和真实专家身份。结果卡、按钮、背景、字号与咨询室及妈妈页保持一致；图标不替代正文说明。没有将结束页等同于咨询总结，未添加新的扣减规则或自行判断咨询结果。

实现集中在 UserConsultationOutcome 和 room_page 的用户结束分支。技术故障与未能到场仍显示原有“未扣减咨询次数”说明，提供重新预约及返回妈妈主页；正常完成只提供查看咨询总结；其他原有分支继续保留对应的总结与重新预约操作。预约取消仍保留原有总结入口，没有在视觉重构中更改业务策略。专家端结束界面不变。

证据：

- [专项设计验证](design-tests.log) **48 项通过**；新增服务器结束后的断连、六类结果的正确操作、普通/双倍字号与短屏详情可达性验证。
- [咨询流程联测](joint-tests.log) **129 项通过**；[静态分析](analyze.log) 3 个文件无问题。
- [方法对比](behavior-checks.json) 确认原离开/重试、入室检查及专家动作、专家结束结果代码保持一致。
- 已实际检查 [Figma 技术故障](figma/technical.png)、[Figma 短屏操作区](figma/short-no-show-actions.png)、[Flutter 正常完成](verified/outcome-completed-390-844-1x.png)、[转介支持](verified/outcome-safety_escalation-390-844-1x.png)、[短屏未到场](verified/outcome-user_no_show-320-568-2x.png) 和 [短屏预约详情](verified/outcome-user_no_show-short-details.png)。测试数据日期与 Figma 示例日期不同，布局规则一致。
- [源清单](source-inventory.json)、[源图指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json) 已保存。没有改写 Session A 截图，没有运行截图清单生成测试；本轮未进行原生通话或发布构建。

本轮只标记 `room#outcome`。咨询总结、行动详情、续购，以及独立咨询路由首次加载/失败仍保留各自范围。预约 107 个增量已 [复核](../20260914-booking-current/REVIEW.md)，沿用现有设计，75 项相关测试通过。期间又新增 29 个 booking-resume 状态，已登记待审；当前观察到 2675 个截图状态，整体任务保持 active。
