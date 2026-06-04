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
    const unavailableHintClass = statusSource.match(/className="([^"]*absolute -top-10 right-0[^"]*)"/)?.[1] ?? "";
    expect(unavailableHintClass).not.toContain("-translate-x-1/2");
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
    expect(statusSource.indexOf("说出完整主谓短句")).toBeLessThan(statusSource.indexOf("出生后首次自主抬头"));
    expect(statusSource.indexOf("2026.05.28")).toBeLessThan(statusSource.indexOf("2025.11.18"));
    expect(statusSource).toContain("<time");
    expect(statusSource).toContain('font-normal text-[#9a8fa5]');
    expect(statusSource).toContain("bg-gradient-to-t from-[#dcf7ed] via-[#cceee1] to-[#76c7ad]");
    expect(statusSource).toContain("const recency = 1 - index / total");
    expect(statusSource).toContain("const hue = 146 + recency * 18");
    expect(statusSource).toContain("const dotSize = 10 + recency * 8");
    expect(statusSource).toContain("mt-4 flex h-7 w-7 shrink-0 items-center justify-center");
    expect(statusSource).toContain("background: `linear-gradient(135deg, #fff 0%, ${softColor} 100%)`");
    expect(statusSource).not.toContain("宝宝微笑");
    expect(statusSource).not.toContain("照片记录");
    expect(statusSource).not.toContain("rounded-full bg-white/80 px-2 py-0.5");
  });

  it("opens a baby sleep report from the baby sleep card", () => {
    expect(statusSource).toContain('type BabyStatusPanelId = "baby-health" | "growth-milestone" | "baby-sleep"');
    expect(statusSource).toContain("const BABY_SLEEP_SUMMARY");
    expect(statusSource).toContain("const BABY_SLEEP_CHART");
    expect(statusSource).toContain("icon: Moon");
    expect(statusSource).toContain("icon: Timer");
    expect(statusSource).toContain("icon: Frown");
    expect(statusSource).toContain("icon: Activity");
    expect(statusSource).toContain("宝宝睡眠报告");
    expect(statusSource).toContain("总睡眠");
    expect(statusSource).toContain("4h 57min");
    expect(statusSource).toContain("最长睡眠");
    expect(statusSource).toContain("3h 08min");
    expect(statusSource).toContain("宝宝睡眠记录");
    expect(statusSource).toContain("按时段看睡眠、活动和哭闹时长");
    expect(statusSource).toContain("sleepMinutes");
    expect(statusSource).toContain("activityMinutes");
    expect(statusSource).toContain("cryMinutes");
    expect(statusSource).toContain("90m");
    expect(statusSource).toContain("00:00");
    expect(statusSource).not.toContain("夜间状态分布");
    expect(statusSource).toContain('title="宝宝睡眠"');
    expect(statusSource).toContain('label: "今日睡眠", value: "4h 57min"');
    expect(statusSource).toContain('action="查看报告"');
    expect(statusSource).toContain('onClick={() => setActiveBabyPanel("baby-sleep")}');
    expect(statusSource).not.toContain("4h57min");
    expect(statusSource).not.toContain("3h08min");
    expect(statusSource).not.toContain('index === 0 || index === 1');
  });
});
