import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const statusSource = readFileSync(resolve(here, "StatusOverviewBody.tsx"), "utf8");

describe("StatusOverviewBody status page copy", () => {
  it("uses the breast health diary wording and agent-assisted CTA", () => {
    expect(statusSource).toContain("乳房健康日记");
    expect(statusSource).toContain("查看《乳房健康日记》");
    expect(statusSource).toContain('title: "涨奶硬块"');
    expect(statusSource).toContain('import momcozyAgentAvatar from "@/assets/momcozy-agent.png"');
    expect(statusSource).toContain("<MaiInlineAvatar />");
    expect(statusSource).not.toContain("查看健康状态");
    expect(statusSource).not.toContain("乳房健康状态");
    expect(statusSource).not.toContain('title: "持续关注"');
  });

  it("marks postpartum recovery progress and shows a non-blocking unavailable hint", () => {
    expect(statusSource).toContain('{ time: "第 1-2 天", status: "已完成"');
    expect(statusSource).toContain('{ time: "第 3-5 天", status: "进行中"');
    expect(statusSource).toContain('import postpartumRecoveryIcon from "@/assets/postpartum-recovery-icon.png"');
    expect(statusSource).toContain("const PostpartumRecoveryIcon");
    expect(statusSource).toContain("icon={<PostpartumRecoveryIcon />}");
    expect(statusSource).toContain("postpartumTrainingHintVisible");
    expect(statusSource).toContain("showPostpartumTrainingHint");
    expect(statusSource).toContain("window.setTimeout");
    expect(statusSource).toContain("1500");
    expect(statusSource).toContain("暂未开通此功能");
    expect(statusSource).toContain("absolute -top-10 right-0");
    expect(statusSource).toContain("继续训练");
    expect(statusSource).not.toContain("-translate-x-1/2");
    expect(statusSource).not.toContain('window.alert("暂未开通此功能")');
    expect(statusSource).not.toContain("const YogaMomIcon");
  });

  it("shows rest as pending and makes lactation trend references clearer", () => {
    expect(statusSource).toContain('待开通 <strong className="font-bold">睡眠</strong> 与 <strong className="font-bold">营养</strong> 功能');
    expect(statusSource).toContain('estimate: "#8a5f7d"');
    expect(statusSource).toContain('band: "#dff4e8"');
    expect(statusSource).toContain("strokeWidth={2.4}");
  });

  it("renames baby care to baby health and opens health information", () => {
    expect(statusSource).toContain('title="宝宝健康"');
    expect(statusSource).toContain('action="查看健康信息"');
    expect(statusSource).toContain('onClick={() => setActiveBabyPanel("baby-health")}');
    expect(statusSource).toContain("自闭症风险筛查");
    expect(statusSource).toContain("生长发育迟缓风险筛查");
    expect(statusSource).toContain("消化系统风险筛查");
    expect(statusSource).toContain("皮肤异常风险筛查");
    expect(statusSource).toContain("认知互动风险筛查");
    expect(statusSource).toContain("宝宝情绪跟踪");
    expect(statusSource).not.toContain('title="尿便与护理"');
    expect(statusSource).not.toContain('action="快速记录"');
  });

  it("adds a growth milestone action and timeline", () => {
    expect(statusSource).toContain('secondaryAction="成长milestone"');
    expect(statusSource).toContain('onSecondaryClick={() => setActiveBabyPanel("growth-milestone")}');
    expect(statusSource).toContain("const BABY_GROWTH_MILESTONES");
    expect(statusSource).toContain("出生后首次自主抬头");
    expect(statusSource).toContain("首次完整自主翻身");
    expect(statusSource).toContain("首次叫妈妈");
    expect(statusSource).toContain("无支撑独自坐稳");
    expect(statusSource).toContain("四点手足爬行");
    expect(statusSource).toContain("说出完整主谓短句");
    expect(statusSource).toContain("照片记录");
  });
});
