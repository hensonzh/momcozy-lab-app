状态卡和日历原先排除子节点语义，却没有为外层 Semantics 配置 onTap，Android 可访问性树因此显示 clickable=false。

Me/Baby 状态卡和日历日期显式绑定已有点击回调；不新增业务动作。回归先复现缺失 tap action，再验证修复，22 项相关页面测试通过。
