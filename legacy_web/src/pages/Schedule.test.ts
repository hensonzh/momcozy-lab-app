import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const scheduleSource = readFileSync(resolve(here, "Schedule.tsx"), "utf8");

describe("Schedule page layout", () => {
  it("moves the reminder control into the plan summary area", () => {
    expect(scheduleSource).not.toContain('<h1 className="text-xl font-extrabold text-foreground tracking-tight">呵护计划</h1>');
    expect(scheduleSource).toContain('aria-label={reminderOn ? "关闭计划提醒" : "开启计划提醒"}');
    expect(scheduleSource).toContain('className="absolute right-3 top-3 z-20 h-9 w-9');
    expect(scheduleSource).toContain('onClick={handleReminderToggleClick}');
  });

  it("shows the agent schedule adjustment note above the next task", () => {
    expect(scheduleSource).toContain('import momcozyAgentAvatar from "@/assets/momcozy-agent.png"');
    expect(scheduleSource).toContain("已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我");
    expect(scheduleSource).toContain("提醒开关");
    expect(scheduleSource).toContain("对话");
    expect(scheduleSource).toContain('navigate("/", { state: { agentPrefill: "我想调整今天的吸乳排期" } })');
  });
});
