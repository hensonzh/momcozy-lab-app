# 独立日记页：衍生设计验收

2026-09-12，仅用户 App。依据 mom/derived/diary-history.md 与设计工程 UserApp.tsx HomePage 的最新日记结构（1049 行起）重新核对。独立 /me/diary 是当天编辑器，不是历史列表；共享 MotherDiaryEditor 的深棕标题、奶油表单、三类标签、滚动字段和固定保存区。SafeArea 外缘改用 warmFormSurface，避免底色接缝。

路由参数切换问题先用测试复现：同一 /me/diary 从 mood 改成 body 时，旧 State 保留 mood；route-before.log 是修复前失败结果。路由 Widget key 现在包含解析后的分类，外部路由切换会加载相应编辑器，未知参数回退 rest。页面内三个标签仍复用同一 Controller，切换保留草稿。

新增 mother_diary_page_test：320/390/430 宽度 × 1x/2x 字号，三分类、已有记录无修改时禁止保存、离开确认并继续填写、离线失败草稿保留、重试保存正确日期与三个分组、保存反馈和关闭。320×568、2x 字号与 260 高键盘同时出现时，输入框可滚动，保存按钮仍可点击。对应 Flutter 渲染图为 test/goldens/design_system/diary-page-*.png；已检查普通表单、大字号、保存成功、失败提示和短屏键盘。键盘图的空白下部是测试中的模拟键盘占位，不是表单留白。

日记页定向 16 项通过，妈妈模块与路由整合回归 68 项通过；全量静态分析无问题。local debug APK 构建通过（Gradle 8.6 秒），普通覆盖安装成功。

模拟器实际打开 /me/diary?section=rest，读取 Mia 当天既有三个分组；切换身体、心情再回到休息。临时选择 5–6 小时后关闭出现确认，继续填写仍保留草稿；再次关闭并放弃后返回 Mia 首页，首页仍显示原 4–5 小时。本次原生检查没有保存或覆盖既有日记。保存成功与离线重试由受控仓储测试验证，不将其表述为本次真实后端写入验证。

证据：native-rest/body/mood、native-discard、native-draft-retained、native-return-home 的 PNG/XML；构建、安装与测试日志均在本目录。独立页标为 Completed，细分补充字段状态仍按各自清单验收。

后续同轮细分状态复核补齐空表单点击提示：空日记可点击保存，显示“先记录一项今天的状态，再保存。”且不调用仓储。原生读取已有记录时仍禁用无修改保存。最终共享组件回归为 diary-states/regression.log 的 77 项；更新后的渲染基线以当前 test/goldens 为准。
