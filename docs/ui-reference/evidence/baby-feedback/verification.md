# 喂养校验、保存撤销、生长资料缺失 — 2026-09-12

重新打开 baby-me-style-sync/images/feeding-validation.png、feeding-saved.png、empty-growth-320.png；读取 UserApp.tsx 的 saveFeeding / undoFeedback / BabyGrowthCurve，以及 styles.css 的 mom-editor-error / baby-save-feedback 和 baby.css 小屏规则。feeding-saved 原截图未显示滚动下方的反馈，位置和动作以 BabyPage 第 1837 行及 undoFeedback 为可追踪依据。

- 喂养校验改为 9 圆角、粉底 #FBE6E6、深红 #923F3F 的紧凑错误条，字号 11 适应移动端阅读。备注在统计说明前方，盾牌说明和错误条按原稿排列。校验仍使用原控制器，无效数据不发请求。
- 首页保存反馈位于睡眠监测之后；保存后自动滚动到反馈。反馈属于刚保存的具体记录及版本，已有睡眠的结束更新、发展观察不会被当作新增记录删除。喂养、尿布、新睡眠、多项生长记录保留符合设计的撤销。
- 撤销沿用 BabyRecordRepository.delete 和 expectedVersion。批量删除已确认的项目不重复删除；网络或响应不确定时保留待确认项，重试同一记录/版本；确定冲突停止重试并指向全部记录。重复点击不产生并行删除，切换宝宝清除当前反馈，旧请求完成不覆盖新宝宝界面。
- 生长资料不完整时不显示不存在的参考曲线说明；已有参考而没有测量时提示“记录后会显示变化”。320 宽度指标切换占满一行。

三宽 320/390/430 与双倍字号覆盖喂养校验、保存、服务删除已生效但响应失败、重试确认和统计恢复。缺少出生日期、缺少出生记录性别、两者均缺三种状态验证完善资料入口及资料补齐后参考范围出现。完整宝宝模块 136 项回归通过，静态分析无问题，APK 构建安装成功。

视觉截图：test/goldens/design_system/baby-feeding-{validation,saved}-*.png、baby-growth-missing-{birth,sex,both}-*.png，以及本目录原生 PNG/XML。

原生本地验证：Mia 账号、Luna 宝宝的喂养基线为“未记录”；未选择方式触发校验；选择瓶喂母乳、填写临时 60 ml 后保存成功；绿色反馈及撤销入口可见；点击撤销成功，重进 Baby 后喂养恢复“未记录”。既有 3.82 kg 生长记录未修改，最终返回 Mia 首页。临时喂养经原有软删除接口撤销，未删除先前记录。错误重试、批量部分失败及资料缺失状态用受控仓库测试，未破坏本地账号的宝宝资料。
