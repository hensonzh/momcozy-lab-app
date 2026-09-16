# Baby 知识来源：Android 真实浏览器与返回

当前已安装 local App、原 Mia 登录会话。实际链为 Me → Baby → 生长知识卡 → WHO 来源 → Chrome → 返回文章 → Baby → Me。未新增宝宝记录、发送消息或购买服务，未重新构建安装 App。

8 张原生窗口和 XML 均已逐张查看；[原始操作记录](actions.jsonl)、[哈希与前驱审计](evidence.json)、[采集步骤工具](capture_steps.py) 留存。每次点击均与前一份 UI 树的可用控件、边界及中心坐标核对。

| 前驱 | 实际操作 | 到达状态 | UI 树 |
| --- | --- | --- | --- |
| 当前登录会话 | 当前已登录 Mia 首页 | [original-mom](original-mom.png) | [XML](original-mom.xml) |
| original-mom | 点击 Baby | [baby-entry](baby-entry.png) | [XML](baby-entry.xml) |
| baby-entry | 点击 更好地了解 Luna / 看成长，关键是同一口径下的连续变化 / 体重、身长和头围需要结合年龄与连续测量来理解，单独一个数字不能说明宝宝的生长状态。 | [knowledge-detail](knowledge-detail.png) | [XML](knowledge-detail.xml) |
| knowledge-detail | 点击 WHO · 儿童生长标准 | [external-open](external-open.png) | [XML](external-open.xml) |
| external-open | 点击 Close | [external-page](external-page.png) | [XML](external-page.xml) |
| external-page | Android 系统返回键 | [source-return](source-return.png) | [XML](source-return.xml) |
| source-return | 点击 关闭 | [baby-return](baby-return.png) | [XML](baby-return.xml) |
| baby-return | 点击 Me | [restored-mom](restored-mom.png) | [XML](restored-mom.xml) |

WHO 页面已加载，并不是只确认启动浏览器。Chrome 首次出现 tips notifications 引导，点击 Close 关闭，没有开启通知。系统 Back 后文章 XML 与进入前完全一致；关闭后 Baby XML 一致，最终 Me/Mia XML 也与原始状态一致。

知识文章的标题、摘要、三条要点、来源、内容说明和提问按钮均在原生窗口中完整显示。首页窗口是入口补充证据；完整页面的宿主长图见 [知识来源报告](../../00-overview/BABY-KNOWLEDGE-SOURCES.md)。外部 WHO 网站只记录落地页与返回边界，未声称遍历或完整截取外部网站。其它五个来源只在宿主测试验证 URL 分发，不能视为设备联网验证。
