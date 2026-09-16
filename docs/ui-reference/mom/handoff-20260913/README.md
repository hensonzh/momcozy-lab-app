# 妈妈首页 Flutter 开发交付包

本目录将 Figma 中的妈妈首页转换为可直接接入 Flutter 项目的实现，覆盖：

- 初始态：尚未完成记录、尚未购买服务包
- 有数据态：泌乳、身体、睡眠和心情已有数据
- 已购服务态：显示「我的陪伴计划」与进行中的 IBCLC 服务包

## 文件结构

```text
lib/
  main.dart                       # 可运行的三状态演示入口
  mom_home.dart                   # 对外导出
  src/
    mom_home_models.dart          # 页面状态、数据和事件回调
    mom_home_theme.dart           # 颜色、圆角、间距和字体规范
    mom_home_screen.dart          # 页面与组件实现
assets/
  images/                         # AI、专家和导航头像
  icons/                          # Figma 原始 SVG 装饰与图标
```

## 接入现有项目

1. 复制 `lib/src`、`lib/mom_home.dart` 和 `assets` 到现有 Flutter 项目。
2. 在 `pubspec.yaml` 中声明 `assets/images` 与 `assets/icons` 两个资源目录；该交付包不依赖第三方 UI 组件库。
3. 页面入口使用：

```dart
MomHomeScreen(
  data: MomHomeData.purchased(),
  callbacks: MomHomeCallbacks(
    onRecordLactation: () {},
    onExpertPlans: () {},
    onServiceProgress: () {},
    onBookConsultation: () {},
  ),
)
```

## 状态映射

| 业务状态 | 数据对象 | 页面表现 |
| --- | --- | --- |
| 首次进入/未记录 | `MomHomeData.initial()` | 引导完成泌乳、身体、休息和心情记录 |
| 已完成今日记录 | `MomHomeData.recorded()` | 展示 AI 分析、奶量与恢复状态 |
| 已购买专家服务包 | `MomHomeData.purchased()` | 在专家入口下显示「我的陪伴计划」与进行中服务 |

正式接入时，建议由 ViewModel/BLoC/Riverpod 将接口数据转换为 `MomHomeData`，页面组件不直接依赖接口字段。

## 设计基准

- Figma 基准宽度：393 px
- 页面水平边距：16 px
- 模块垂直间距：14 px
- 主卡片圆角：22 px
- 页面字体：Noto Sans SC；未安装时回退到 PingFang SC / 系统无衬线字体
- 底部导航在 Flutter 中按真实 App 行为固定展示，页面内容独立滚动

## 开发注意事项

- `assets/images` 中的人像为设计占位资源。上线前应替换为已获得授权的 AI/IBCLC 头像或业务 CDN 地址。
- 记录、趋势、服务进度和预约咨询均通过 `MomHomeCallbacks` 注入，方便接入现有路由和埋点系统。
- 头像与关键图标由 Figma 节点直接导出为本地 PNG；水滴装饰使用 `CustomPainter` 实现，交付包不依赖任何临时资源链接。
- 当前环境未安装 Flutter SDK，因此已完成结构与静态代码检查，但需要在业务项目中执行 `flutter pub get`、`flutter analyze` 和真机视觉回归。

## Figma 对照

- 基准状态：<https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=19-2>
- 初始状态：<https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=88-2>
- 已购服务状态：<https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=88-111>
