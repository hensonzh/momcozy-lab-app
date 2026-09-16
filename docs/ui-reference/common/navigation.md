# 五入口底部导航

- ID：`common/navigation`
- 类型：component
- 参考来源：original
- 设计源码：[UserShell](../source/src/pages/UserApp.tsx#L190)，第 190–207 行
- Flutter：`lib/app/mom_bottom_navigation.dart`
- Route / 入口：`/me /baby / /schedule /more`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../common/reference/navigation.png)

原始路径：`me-agent-style-sync/diary-followup/15-navigation-me.png`；SHA-256：`e29f8b4fbc00c27663eadc304a027609f53db0843c2ce9346bfa49f8ba0579f5`。


复核记录：逐项对照 me-agent.css 379–466 行和现场浏览器实测：SVG、78px+安全区、选中底、头像外环、标签间距已对齐。五入口模拟器切换均正确；320/390/430 三宽、两倍字号及子页隐藏测试通过。系统字体字形与浏览器有细微差异，字号放大时导航允许增高。

- functional_evidence: [evidence/navigation/interaction-results.json](../evidence/navigation/interaction-results.json)
- functional_evidence: [evidence/navigation/verification.txt](../evidence/navigation/verification.txt)
- visual_evidence: [evidence/navigation/me.png](../evidence/navigation/me.png)
- visual_evidence: [evidence/navigation/baby.png](../evidence/navigation/baby.png)
- visual_evidence: [evidence/navigation/cozymate.png](../evidence/navigation/cozymate.png)
- visual_evidence: [evidence/navigation/schedule.png](../evidence/navigation/schedule.png)
- visual_evidence: [evidence/navigation/more.png](../evidence/navigation/more.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
