import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const scheduleSource = readFileSync(resolve(here, "Schedule.tsx"), "utf8");

describe("Schedule today task explanation", () => {
  it("explains that the plan is based on pre-plan data and plan-type methods", () => {
    expect(scheduleSource).toContain("依据上次制定前读取到的产后阶段、奶量/喂养记录和原有任务节奏");
    expect(scheduleSource).toContain("新增记录只用于看执行反馈");
    expect(scheduleSource).toContain("追奶重点是增加有效移出机会");
    expect(scheduleSource).toContain("减奶重点是循序减少频次或时长");
    expect(scheduleSource).toContain("稳奶重点是稳定关键排乳窗口");
    expect(scheduleSource).not.toContain("不是按你当前");
    expect(scheduleSource).not.toContain("当前这一刻");
    expect(scheduleSource).not.toContain("不会自动改写这份已经生成的计划");
  });

  it("does not show the robot icon in the explanation dialog", () => {
    expect(scheduleSource).not.toContain(" Bot,");
    expect(scheduleSource).not.toContain("<Bot");
    expect(scheduleSource).toContain("whitespace-pre-line");
  });
});
