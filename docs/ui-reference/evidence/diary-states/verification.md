# 日记补充字段与空表校验

2026-09-12，仅用户 App。本轮在独立日记页验收后，继续逐项复核 mom/state-05、07、08、10。

## 设计依据与修改

重新读取设计工程 UserApp.tsx HomePage 1049–1128 行、saveMomStatus 888 行，以及 src/styles/me-diary.css 的当前暖色日记规则和 styles.css 的 mama-app 容器断点。旧 09-06 状态图仅保留交互追踪，新源码和 09-08 日记组件样式优先。

补充休息与如厕折叠标题增加“可选”，休息填写任一补充字段后显示“已填写”；两倍字号时提示换行。再次入睡使用三段选项，不适影响使用三列卡片；休息原因的“可多选”移到标题右侧。390 及更窄屏的白天休息和原因网格使用两列，430 宽度分别四列和三列，大字号由共享 ChoiceField 再折行。

空表校验与当前设计 saveMomStatus 文案保持一致：点击“保存今天的记录”显示“先记录一项今天的状态，再保存。”，自动滚到提示，仍允许继续填写。控制器的 canSave 和非空限制不变，空表没有仓储调用；已有记录无修改、加载中或提交中仍禁用保存。测试先复现原本空表按钮直接禁用，见 empty-before.log。填写内容后错误提示隐藏，正常保存和失败重试继续使用原流程。

## 功能和视觉验证

新增 mother_diary_states_test，320/390/430 × 1x/2x 共六组完整操作：空表提示且零写入；休息补充展开、单选、多选、折叠再展开、保存具体字段；不适部位触发程度与影响；如厕展开、排尿与排便保存；清空全部不适部位后再次保存，程度与影响为 null，如厕记录保留。共三次有效保存使用受控仓储，没有更改 API 或后端规则。

最新整合回归 77 项通过，包含妈妈模块、路由与共享选择器；静态分析无问题；local debug APK 构建安装通过。更新了受此次标题和空表按钮影响的已有图像基线，新增 diary-state-{rest-stretch,rest-day,rest-disruptions,body-discomfort,body-urination,body-bowel,empty-validation}-*.png。已目视检查普通展开、大字号长选项、盆底末尾与空表提示，内容可滚动、保存按钮固定可达。

当前设计浏览器重新捕获三组 viewport/full 图：mom/diary-rest-expanded、diary-body-conditional、diary-body-pelvic。捕获脚本隔离演示状态，屏蔽全部 API 与外部请求。设计的 applyDemoHealthSeed 每次加载都重新生成当天示例记录，清空 localStorage 字段后刷新无法保留空表，因此本轮不声称取得最新浏览器空表截图；state-10 对照已有原稿、saveMomStatus 源码与实际 Flutter 空表渲染验证。

模拟器从 Mia 首页打开原生日记弹窗，展开休息补充，切换身体并临时选中腰背，核对条件项和如厕展开。退出时放弃临时修改，返回首页，既有记录保持原值。原生过程不保存、不覆盖测试账号日记；写入与条件字段清理由仓储测试验证。PNG/XML 见 native-rest-expanded、native-body-conditional、native-body-pelvic 和 native-restored-home。
