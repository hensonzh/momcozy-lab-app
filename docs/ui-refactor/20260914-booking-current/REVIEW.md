# 预约新增状态复核

逐项核对 107 个新增条目的真实路由与触发条件：29 个预约预检查、35 个时段选择、43 个恢复/取消状态。目标均为已有预约页、信息采集页或妈妈页。实际查看专家菜单及取消后服务器状态已变化的恢复弹窗，没有新增页面布局。

沿用 [预约与流程设计](../20260914-booking/HANDOFF.md) 及 [信息采集设计](../20260914-intake/HANDOFF.md)。现有 [booking、appointment_detail、date_time_picker、intake 测试](tests.log) 共 **75 项通过**。这些条目已标为现有设计覆盖；没有修改生产代码、视觉基线或 Session A 截图。完整记录见 [源清单](source-inventory.json)。
