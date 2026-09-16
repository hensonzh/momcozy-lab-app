# 逐状态映射收尾：13 条待定位项的处理

本轮将剩余 13 条逐项定位，不再产生额外设备、字号、错误码或时序矩阵。34 个页面定义共 213 条状态行已有明确处置；有截图的状态并不因此自动完成所有历史版本、入口及浮层验收。

| 原待定位项 | 处理及证据 |
| --- | --- |
| 日记加载 | 确认实际缺图，新增 [完整截图与加载完成断言](../03-mom/mom-diary-loading/README.md)。 |
| 泌乳加载 | 复用 [已有运行截图](reused-state-evidence/lactation-loading/README.md)，源码指纹一致。 |
| 预约加载 | 复用 [已有运行截图](reused-state-evidence/appointment-loading/README.md)，源码指纹一致。 |
| 预约咨询中 | 复用 [已有运行截图及返回咨询室动作](reused-state-evidence/appointment-in-progress/README.md)。 |
| 预约完成 | 复用 [已有运行截图及查看总结动作](reused-state-evidence/appointment-completed/README.md)。 |
| 信息采集校验 | 新增 [实际提交后的授权冲突完整长图](../08-expert-service/intake-consent-validation/README.md)。前端必填不完整时提交禁用，不能通过正常点击生成控制器内的必填错误文案；已有未填写图复用。 |
| PDF 多页与缩放 | 修正英文文件 ID 和中文状态名混用；既有原生第一页、第二页、放大图均存在。原生图记录其拍摄版本，当前控件改版资料在媒体页面补充索引保留。 |
| 全屏播放 | 原选原生图实际为暂停；新增 [播放中截图](../11-media/media-fullscreen-playing/README.md)，暂停按钮可见。视频画布来自假平台，真实解码沿用原生资源操作报告。 |
| 全屏暂停 | 复用 [暂停且已定位的全屏图](../11-media/media-fullscreen/README.md)。 |
| 全屏进度 | 同上，时间 6:17:28 / 12:34:56、定位进度和静音均可见；同一个画面共享引用。 |
| 全屏控件显示与隐藏 | 当前 `_ProductAssetVideoViewport` 持续构建控制条，无自动隐藏和点击隐藏分支；只记录实际常驻控件，不虚构隐藏态。 |
| 全屏返回 | 修正原生状态名称匹配；退出恢复内嵌图与实际退出操作均已有。当前单项控件测试同样实际退出全屏。 |
| 动作评估 | 无正常用户入口，保留代码及边界清单；不当成用户可达截图缺口。 |

另修正三处状态对应：日记空记录改为 `diary-page-rest`（0/3）；预约咨询中改为 `booking-recovery-current-cancel-in-progress-return`；咨询正常结束改为 `consultation-journey-current-completed-outcome`，不再用总结目标页代替。

## 本轮运行与复用依据

- [3 个定向场景严格通过](runs/20260914-state-map-final/strict.log)：日记加载后恢复、信息采集真实点击提交后授权冲突、390 / 1x 视频播放暂停定位全屏返回。未运行其他尺寸组合。
- [相关测试静态分析](runs/20260914-state-map-final/analyze.log)；[本轮源码指纹](runs/20260914-state-map-final/source-hashes.json)。
- [4 张已有运行图复用审计](reused-state-evidence/audit.json)：逐张目视检查，内容全部位于窗口内；保留来源、测试日志和匹配源码指纹。
- 新增 3 张独立状态图；同一视频场景顺带输出的原有控件图按原状态归并，不计作新页面或新增需求。
- 新图已目视检查。日记和全屏无纵向溢出；信息采集从顶部表单至授权、错误说明和底部保存按钮完整显示。

## 尚不能据此宣称的结论

状态映射空缺清零不等于全 App 最终验收。各页历史截图、当前设计改版截图和原生截图仍带各自版本及运行环境边界；后续验收只沿已有 34 页、35 类浮层及具名操作报告核对，不扩大组合。全局状态继续为 `NOT_PROVEN`。
