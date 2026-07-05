# 旧 Web Reference Screenshots

> 状态：执行说明 v0.1  
> 范围：固化旧版 Vite + React + Capacitor Web App 的移动端首屏 reference screenshot，用于 Flutter UI/UX 对齐评审。  

---

## 1. 目的

这些截图是旧 Web 的视觉基线，不是 Flutter 输出。

Flutter golden 用来锁定 Flutter 当前实现；旧 Web reference screenshot 用来回答另一个问题：Flutter 是否仍然保留旧 Web 的页面结构、信息层级、关键控件和首屏视觉比例。

---

## 2. 生成命令

从 `MomCozyApp/` 目录运行：

```bash
npm run ui:legacy-reference
```

脚本会自动启动 Vite dev server，使用 Playwright 打开固定移动视口并保存截图。

默认配置：

| 配置 | 默认值 |
|---|---|
| Viewport | `390x844` |
| Host | `127.0.0.1` |
| Port | `4187` |
| Timezone | `Asia/Shanghai` |
| 固定时间 | `2026-07-03T09:00:00+08:00` |
| 输出目录 | `test/screenshots/legacy_web/compact_390x844/` |

可通过环境变量覆盖：

```bash
MOMCOZY_REFERENCE_WIDTH=430 \
MOMCOZY_REFERENCE_HEIGHT=932 \
MOMCOZY_REFERENCE_PORT=4188 \
npm run ui:legacy-reference
```

---

## 3. 覆盖路由

当前 reference 覆盖旧 Web 的主要页面：

```text
/
/status
/schedule
/device
/device/manage
/device/user
/w1
/hospital-bag-cart
/ibclc-chat.html
/calibration
/community
```

每次生成会同时写入 `manifest.json`，记录截图文件、路由、viewport 和 sha256，便于评审时确认截图是否发生变化。

`manifest.json` 中的 `consoleErrorCount` 仅作为诊断信息。旧 Web 在本地没有后端服务时，部分页面可能会记录 API/媒体加载错误；只要截图本身呈现的是旧 Web 预期页面状态，就可以作为当前 reference。

---

## 4. 使用规则

- 旧 Web reference screenshot 变化必须说明原因。
- Flutter UI 评审时，应同时打开旧 Web reference 和 Flutter golden 对照。
- 如果 Flutter 与旧 Web 不一致，需要标记为 bug 或产品决策，不能默认归因于“原生重构”。
- 后续补多视口时，建议优先补 `360x800`、`390x844`、`430x932`。

---

## 5. 注意事项

脚本默认固定浏览器时间并降低动画影响，以减少日历、时间、动画带来的截图漂移。

如果本机没有可用 Chrome 或 Playwright Chromium，先执行：

```bash
npx playwright install chromium
```
