# 日期选择器注入时钟回归

备注采集器跨模块回归在日历日期跨到 9 月 14 日后发现两张既有金图漂移：Baby 生长记录日期选择器及日程新增日期选择器仍用系统当天作为“今天”，但页面、业务校验和测试使用注入的 9 月 13 日时钟。修复前增加 `DatePickerDialog.currentDate` 断言，两项均失败，见 [红测试](mom-date-clock-red.log)。未修改金图基线掩盖漂移。

## 最小修复

- Baby 日期字段将已有 Controller.today（记录时区）传给日期选择器 currentDate。
- PersonalScheduleEditor 新增默认 DateTime.now 的可注入 now，由 SchedulePage 传入其已有 now，日期选择器使用该时钟。
- 两条实际路由测试明确断言日期选择器 currentDate 与各自注入日期一致。默认运行仍使用真实时钟，没有硬编码测试日期。

## 验证

- Baby 路由、日程路由、日程编辑器及 Controller、Baby 编辑状态五份测试共 **60 项通过**，见 [绿测试](mom-date-clock-green.log)。
- Auth / Baby / Schedule 三份实际路由采集共 **27 项通过**，见 [严格采集日志](runs/20260913T202334-targeted/capture.log)、[命令](runs/20260913T202334-targeted/capture-command.json) 和 [退出码](runs/20260913T202334-targeted/capture-result.json)。
- 修复后 267 张既有视口及长图与采集前完全逐字节一致，见 [比较结果](mom-date-comparison.json)。实际查看了 [Baby 日期选择器](../raw/test/goldens/ui_inventory/baby-journey-growth-date-calendar-393.png) 和 [日程日期选择器](../raw/test/goldens/ui_inventory/schedule-journey-date-picker-393.png)，13 日为选中/当天，14 日未被错误描边。
- 当前源文件见 [SHA 清单](date-clock-source-hashes.json)。[泌乳补验的全仓静态检查](mom-milk-validation-analyze.log) 在上述修改后通过。

两项此前失败现已解决；原始失败图片与日志继续保留在 [备注报告](MOM-NOTE-BOUNDARIES.md)。本轮未重建或执行原生 App，不将这组回归成功外推为全 App 覆盖完成。
