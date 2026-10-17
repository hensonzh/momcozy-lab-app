# 旧 App UI 截图清退记录

核对日期：2026-10-17。仅处理 `app/` 本地工作树，不参考或同步 `momcozy-lab-demo` 远端；不修改、部署服务端，也不覆盖本工作树其他未提交改动。

## 已清退

- `docs/app-ui-inventory/`、`docs/ui-reference/`、`docs/ui-refactor/` 的旧截图证据、索引和生成脚本：共 37,725 个跟踪文件，其中 17,225 张图片。删除清单见本轮本机的 `/tmp/momcozy-legacy-evidence-removal-manifest.json`。三份已有未提交编辑的 `docs/ui-refactor/*/HANDOFF.md` 保留，仅去掉失效的本地图片链接。
- 与上述证据库一对一的采集、索引、校验入口和脚本测试；旧图片路径的设计契约断言不再作为产品验收条件。
- 删除 `test/goldens/ui_inventory/` 的 3,765 张及 `test/goldens/ui_refactor/` 的 221 张旧 Golden，另删除 Me/旧五标签导航与 More 旧视觉专属的 9 张 `design_system` 图片；逐一移除对应 `matchesGoldenFile` 断言、旅程 JSON 输出、`MOMCOZY_UI_INVENTORY_DIR` 测试注入接口与 632 行旧截图采集绑定。认证、记录、媒体、Agent 和账户等行为断言保留在普通或现用 Golden 测试中。
- 删除旧导航、Baby 首页/Figma 的 3 个纯截图生成测试；清退 Me 旧截图输出及旧五标签导航、More 专属快照断言，保留兼容路径的导航可用性和资料、记录、表单行为测试。历史设计契约图片与对照记录仍作归档；已将指向已删除生成测试/Golden 的可执行路径更新为现行行为测试或标记为历史来源。

## 保留边界

- `test/goldens/chat_first/` 是新对话优先产品回归；其他仍被运行的设计系统、登录、媒体、设备等 Golden 要按实际引用单独核对，不能整体删除 `test/goldens/`。
- `assets/images/` 包含运行期图片，不能因截图证据退役而删除。
- 认证、隐私、记录、Agent 附件/重连、媒体、路由/深链等共享行为继续测试；旧五标签 UI 的视觉断言与共享行为分离，兼容入口不能仅因旧截图清退而破坏。
- 服务端 API、数据库、部署和仍供兼容路径使用的客户端协议不属于本轮清理。删除客户端旧页面和 API 必须另行确认消费者与替代覆盖。

## 验收

1. 搜索已清退目录、`MOMCOZY_UI_INVENTORY_DIR` 和旧采集脚本的可执行引用；不能留下悬空测试入口。
2. 验收已运行：`flutter analyze --no-pub` 无问题；`flutter test --no-pub --concurrency=8 --exclude-tags=golden` 1,139 通过、2 跳过；`flutter test --no-pub --concurrency=8 --tags=golden` 379 通过、6 跳过；`python3 -m unittest discover -s scripts/tests -p 'test_*.py'` 106 通过；`git diff --check` 通过。
3. 不涉及模拟器刷新；如以后刷新 Android 模拟器，必须用 `cd app && make local-dev-refresh` 创建并登录全新本地测试账号。
